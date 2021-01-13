terraform {
  backend "azurerm" {
  }
}

provider "azurerm" {
  version = "=2.41.0"
  features {}
}

module "dc" {
  for_each       = { for dc in var.dcs : dc.name => dc }
  source         = "./datacenter"
  location       = each.value["location"]
  address_space  = each.value["address_space"]
  subnet_prefix  = each.value["subnet_prefix"]
  vm_count       = each.value["vm_count"]
  cluster_prefix = var.cluster_prefix
  dc_prefix      = each.key
  vm_admin_username = var.vm_admin_username
  vm_admin_password = var.vm_admin_password
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
  vnets = [
    for dc_prefix, dc in module.dc :
    dc.dc_vnet
  ]

  vnet_pairs = [
    for pair in setproduct(local.vnets, local.vnets) :
    {
      rg_name          = pair[0].resource_group_name,
      vnet_name        = pair[0].name,
      remote_vnet_id   = pair[1].id,
      remote_vnet_name = pair[1].name
    }
    if pair[0].id != pair[1].id
  ]
  # tf count/for_each value should be derived from input
  vnet_pair_count = length(var.dcs) * length(var.dcs) - length(var.dcs)
}

# enable global peering between the two virtual network
resource "azurerm_virtual_network_peering" "cassandra" {
  count                        = local.vnet_pair_count
  name                         = "${local.vnet_pairs[count.index].remote_vnet_name}-vnpeer"
  resource_group_name          = local.vnet_pairs[count.index].rg_name
  virtual_network_name         = local.vnet_pairs[count.index].vnet_name
  remote_virtual_network_id    = local.vnet_pairs[count.index].remote_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false
}
