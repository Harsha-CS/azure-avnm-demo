output "role_assignment_id" {
  value = azurerm_role_assignment.example[*].id
  description = "The resource id of the role assignment"
}
