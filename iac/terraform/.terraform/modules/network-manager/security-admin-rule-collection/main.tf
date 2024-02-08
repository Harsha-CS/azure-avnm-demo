resource "azurerm_network_manager_admin_rule_collection" "rule-collection" {
  name                            = var.name
  security_admin_configuration_id = var.security_configuration_id
  network_group_ids               = var.network_group_id
}