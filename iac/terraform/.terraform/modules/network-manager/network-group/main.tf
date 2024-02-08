resource "azurerm_network_manager_network_group" "network_group" {
  name               = var.name
  description        = var.description
  network_manager_id = var.network_manager_id
}
