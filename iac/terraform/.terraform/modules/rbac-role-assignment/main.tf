resource "random_uuid" "guid" {
  count = length(var.role_details)
}

resource "azurerm_role_assignment" "example" {

  for_each = {
    for role in var.role_details.role_definition_id : role_details.role_definition_id => role
  }

  count = length(var.role_details)
  
  name               = resource.random_uuid.guid[count.index].result
  scope              = var.scope
  role_definition_id = each.value
  principal_id       = var.principal_id

}


