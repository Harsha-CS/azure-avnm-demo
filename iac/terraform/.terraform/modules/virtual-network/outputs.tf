output "name" {
  value       = azurerm_virtual_network.vnet.name
  description = "The name of the virtual network"
}

output "id" {
  value       = azurerm_virtual_network.vnet.id
  description = "The id of the virtual network"
}

output "subnets" {
  value       = azurerm_virtual_network.vnet.subnet[*]
  description = "The subnet objects created"
}