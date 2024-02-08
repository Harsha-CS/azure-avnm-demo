output "name" {
  value       = azurerm_log_analytics_workspace.log_analytics_workspace.name
  description = "The name of the log analytics workspace"
}

output "id" {
  value       = azurerm_log_analytics_workspace.log_analytics_workspace.id
  description = "The resource id of the log analytics workspace"
}

output "location" {
  value       = azurerm_log_analytics_workspace.log_analytics_workspace.location
  description = "The region of the log analytics workspace"
}

output "workspace_id" {
  value       = azurerm_log_analytics_workspace.log_analytics_workspace.workspace_id
  description = "The workspace id"
}