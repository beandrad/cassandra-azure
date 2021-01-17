terraform {
  backend "azurerm" {
  }
}

provider "azurerm" {
  version = "=2.41.0"
  features {}
}

module "dc" {
  for_each          = { for dc in var.dcs : dc.name => dc }
  source            = "./datacenter"
  location          = each.value["location"]
  address_space     = each.value["address_space"]
  subnet_prefix     = each.value["subnet_prefix"]
  vm_count          = each.value["vm_count"]
  cluster_prefix    = var.cluster_prefix
  dc_prefix         = each.key
  vm_admin_username = var.vm_admin_username
  vm_admin_password = var.vm_admin_password
}

data "azurerm_subscription" "current" {
}

locals {
  vms = flatten([
    for dc_prefix, dc in module.dc : [
      for vm in dc.dc_vm :
      {
        rg_name            = vm.resource_group_name
        name               = vm.name
        private_ip_address = vm.private_ip_address
        dc_prefix          = dc_prefix
        public_ip_address  = vm.public_ip_address
      }
    ]
  ])

  vnet_pairs = {
    for pair in setproduct(var.dcs, var.dcs) : "${pair[0].name}-${pair[1].name}" =>
    {

      rg_name          = "${var.cluster_prefix}-${pair[0].name}-rg",
      vnet_name        = "${var.cluster_prefix}-${pair[0].name}-vn",
      remote_vnet_id   = "${data.azurerm_subscription.current.id}/resourceGroups/${var.cluster_prefix}-${pair[1].name}-rg/providers/Microsoft.Network/virtualNetworks/${var.cluster_prefix}-${pair[1].name}-vn",
      remote_vnet_name = "${var.cluster_prefix}-${pair[1].name}-vn"
    }
    if pair[0].name != pair[1].name
  }
}

# enable global peering between the two virtual network
resource "azurerm_virtual_network_peering" "cassandra" {
  for_each                  = local.vnet_pairs
  name                      = "${each.value.remote_vnet_name}-vnpeer"
  resource_group_name       = each.value.rg_name
  virtual_network_name      = each.value.vnet_name
  remote_virtual_network_id = each.value.remote_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false

  depends_on = [module.dc]
}
