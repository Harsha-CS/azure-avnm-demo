output "name" {
  value       = azurerm_network_manager_network_group.network_group.name
  description = "The name of the network group"  
}

output "id" {
  value       = azurerm_network_manager_network_group.network_group.id
  description = "The id of the network group"
}