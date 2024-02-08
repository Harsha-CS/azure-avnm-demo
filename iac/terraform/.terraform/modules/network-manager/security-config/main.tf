resource "azurerm_network_manager_security_admin_configuration" "security-config" {
  name                                          = var.name
  description                                   = var.description
  network_manager_id                            = var.network_manager_id
  apply_on_network_intent_policy_based_services = var.apply_on_network_intent_policy_based_services
}