#!/usr/bin/env bash
set -euo pipefail

# Load configuration
echo -e "\n\e[34m»»» \e[96mLoading configuration\e[0m..."
if [ $# -eq 0 ]; then
    config_path="dev-config.yaml"
else
    config_path="$1"
fi
config=$(yq e -j $config_path)

# Authenticate against Azure
echo -e "\n\e[34m»»» \e[96mAuthenticating against Azure\e[0m..."
clientId=$(echo $config | jq -r '.terraform.clientId')
clientSecret=$(echo $config | jq -r '.terraform.clientSecret')
subscriptionId=$(echo $config | jq -r '.terraform.subscriptionId')
tenantId=$(echo $config | jq -r '.terraform.tenantId')
az login --service-principal --username $clientId \
    --password $clientSecret --tenant $tenantId
az account set --subscription $subscriptionId
export ARM_CLIENT_ID=$clientId
export ARM_CLIENT_SECRET=$clientSecret
export ARM_SUBSCRIPTION_ID=$subscriptionId
export ARM_TENANT_ID=$tenantId

# Init terraform
echo -e "\n\e[34m»»» \e[96mInitialising terraform\e[0m..."
rgName=$(echo $config | jq -r '.terraform.backend.rgName')
saName=$(echo $config | jq -r '.terraform.backend.saName')
containerName=$(echo $config | jq -r '.terraform.backend.containerName')
accessKey=$(az storage account keys list --resource-group ${rgName} --account-name ${saName} | jq .[0].value -r)
tfstateKeyName="cassandra.tfstate"

terraform init -input=false -reconfigure \
    -backend-config="resource_group_name=${rgName}" \
    -backend-config="storage_account_name=${saName}" \
    -backend-config="container_name=${containerName}" \
    -backend-config="access_key=${accessKey}" \
    -backend-config="key=${tfstateKeyName}"

# Create tfvars file
echo -e "\n\e[34m»»» \e[96mCreating tfvars file\e[0m..."
tfvarsFile="cassandra.tfvars"
clusterPrefix=$(echo $config | jq -r '.clusterPrefix')
environment=$(echo $config | jq -r '.environment')
maxDcSeedCount=$(echo $config | jq -r '.maxDcSeedCount')
tfClusterPrefix=$(echo $clusterPrefix | tr -d ' ' | tr  '[:upper:]' '[:lower:]')
query=('[.datacenters[]
    | {name: .name, location: .location, vm_count: .vmCount, 
    address_space: .addressSpace, subnet_prefix: .subnetPrefix}]')
dcs=$(echo $config | jq -r "$query")
vmAdminUsername=$(echo $config | jq -r '.vmAdminUsername')
vmAdminPassword=$(echo $config | jq -r '.vmAdminPassword')
echo "cluster_prefix = \"$tfClusterPrefix\"" > $tfvarsFile
echo "dcs = $dcs" >> $tfvarsFile
echo "vm_admin_username = \"$vmAdminUsername\"" >> $tfvarsFile
echo "vm_admin_password = \"$vmAdminPassword\"" >> $tfvarsFile

# Deploy cassandra cluster
echo -e "\n\e[34m»»» \e[96mDeploying Cassandra cluster\e[0m..."
terraform apply -input=false -auto-approve -var-file=$tfvarsFile
terraform plan -input=false -detailed-exitcode -out=cassandra.tfplan -var-file=$tfvarsFile
if [ "$?" -ne 0 ]; then
    echo "Terraform plan after apply failed"
    exit 1
fi

# Configure cassandra nodes
echo -e "\n\e[34m»»» \e[96mConfiguring Cassandra nodes\e[0m..."
vms=$(terraform output -json cassandra_vm)
seeds=()
while read -r dcName; do
    query=".[] | select(.dc_prefix == \"$dcName\" ) | .private_ip_address"
    readarray -t private_ips < <(echo $vms | jq -r "$query")
    dc_seeds=( ${private_ips[@]:0:$maxDcSeedCount} )
    seeds+=(${dc_seeds[@]})
done < <(echo $config | jq -r '.datacenters | .[] | .name')
seeds=$(IFS=,; echo "${seeds[*]}")

for vm in $(echo "${vms}" | jq -r '.[] | @base64'); do
    vm=$(echo $vm | base64 --decode | jq -r)
    rgName=$(echo $vm | jq -r '.rg_name')
    vmName=$(echo $vm | jq -r '.name')
    vmPrivateIp=$(echo $vm | jq -r '.private_ip_address')
    dcName=$(echo $vm | jq -r '.dc_prefix')
    az vm run-command invoke --command-id RunShellScript \
        --resource-group $rgName \
        --name $vmName \
        --scripts "bash /tmp/setup-cassandra.sh '$clusterPrefix $environment' '$seeds' '$vmPrivateIp' $dcName"
done

# Add prometheus service monitor
# create service-monitor-values.yaml
echo -e "\n\e[34m»»» \e[96mAdding prometheus service monitor\e[0m..."
chartConfig="/tmp/service-monitor-values.yaml"
publicIps=$(echo $vms | jq -j '.[] |  "    - \(.public_ip_address)\\n"')
cp service-monitor-values.yaml.template $chartConfig
sed -i "s/remote_ips: <remote_ips>/remote_ips:\n$publicIps/" $chartConfig
export HELM_EXPERIMENTAL_OCI=1
helm chart pull poste.azurecr.io/charts/remote-service-monitor:0.1.0
helm chart export poste.azurecr.io/charts/remote-service-monitor:0.1.0 -d /tmp/charts
helm upgrade --install cassandra-monitor --values $chartConfig /tmp/charts/remote-service-monitor
