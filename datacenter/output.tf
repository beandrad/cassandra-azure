output "dc_vm" {
  value       = azurerm_linux_virtual_machine.dc.*
  sensitive   = false
  description = "DC nodes"
}

output "dc_vnet" {
  value       = azurerm_virtual_network.dc
  sensitive   = false
  description = "virtual network name of DC"
}
