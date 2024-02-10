resource "azurerm_policy_definition" "avnm_network_group_member" {
  name         = var.name
  display_name = var.display_name
  description  = var.description
  policy_type  = "Custom"
  mode         = var.mode

  metadata = <<METADATA
    {
      "category": "${var.category}"
    }
  METADATA

  parameters = <<PARAMETERS
  ${var.policy_parameters}
  PARAMETERS

  policy_rule = <<POLICY_RULE
  ${var.policy_rule}
  POLICY_RULE
}



