resource "azurerm_network_manager_admin_rule" "rule" {
  for_each = {
      for rule in var.security_rules: rule.name => rule
  }

  name                    = each.value.name
  description             = each.value.description
  action                  = each.value.action
  direction               = each.value.direction
  priority                = each.value.priority
  protocol                = each.value.protocol
  source_port_ranges      = each.value.source_port_ranges
  destination_port_ranges = each.value.destination_port_ranges

  dynamic "source" {
    for_each = each.value.source
    content {
      address_prefix_type = source.value.address_prefix_type
      address_prefix      = source.value.address_prefix
    }
  } 

  dynamic "destination" {
    for_each = each.value.destination
    content {
      address_prefix_type = destination.value.address_prefix_type
      address_prefix      = destination.value.address_prefix
    }
  }

  admin_rule_collection_id = var.security_rule_collection_id
}
