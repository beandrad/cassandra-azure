# Cassandra multi datacenter cluster

This configuration automates the deployment of a multi datacenter Cassandra cluster. Each datacenter can be deployed in a different Azure region and it has its own vnet. The datacenters are connected through vnet peering. The current implementation deploys one rack per datacenter, but the configuration could be extended to support multiple racks.

## Requirements

- bash >=v4.0
- Terraform >=0.13
- [yq](https://github.com/mikefarah/yq) >=4.0 
- jq
- az cli

## Deployment

In order to create the Cassandra cluster follow the next steps:
1. Create a yaml config file: make a copy of [config.yaml.template](./config.yaml.template) and update the values.
2. Deploy and configure the cluster:
 ```bash
 bash deploy-cassandra.sh <path to config file>
 ```
 To delete the cluster run the following command, make sure that the terraform `ARM_*` environment variables are set.
 ```
 terraform destroy -var-file=cassandra.tfvars
 ```

## Configuration

The configuration file contains the following settings:

- `clusterPrefix`: used to prefix related Azure resources.
- `environment`: "`clusterPrefix` `environment`" is the cluster name.
- `maxDcSeedCount`: maximum number of nodes per datacenter used as cluster seeds. Using all the nodes as seeds creates performance issues in large clusters.
- `vmAdminUsername`/`vmAdminPassword`: admin credentials for cluster nodes.
- `datacenters`: configuration of each Cassandra datacenter.
- `terraform`: Azure credentials and backend configuration.
