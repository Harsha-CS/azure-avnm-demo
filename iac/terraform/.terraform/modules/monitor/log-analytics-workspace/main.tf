# Create a Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku               = local.log_analytics_sku
  retention_in_days = var.retention_in_days

  tags = var.tags

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}

# Configure diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "diag-base" {
  depends_on = [azurerm_log_analytics_workspace.log_analytics_workspace]

  name                       = "diag-base"
  target_resource_id         = azurerm_log_analytics_workspace.log_analytics_workspace.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "SummaryLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

module "data_collection_endpoint" {

  source = "../data-collection-endpoint"

  name                = "dce${var.name}${var.location}"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags

}

module "data_collection_rule_windows" {
  depends_on = [
    module.data_collection_endpoint,
    azurerm_log_analytics_workspace.log_analytics_workspace]

  source = "../data-collection-rules/windows"

  name                        = "dcr-windows-${var.name}"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = module.data_collection_endpoint.data_collection_endpoint_id
  law_resource_id             = azurerm_log_analytics_workspace.log_analytics_workspace.id
  law_name                    = azurerm_log_analytics_workspace.log_analytics_workspace.name

  tags = var.tags
}

module "data_collection_rule_linux" {
  depends_on = [
    module.data_collection_endpoint,
    azurerm_log_analytics_workspace.log_analytics_workspace]

  source = "../data-collection-rules/linux"

  name                        = "dcr-linux-${var.name}"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = module.data_collection_endpoint.data_collection_endpoint_id
  law_resource_id             = azurerm_log_analytics_workspace.log_analytics_workspace.id
  law_name                    = azurerm_log_analytics_workspace.log_analytics_workspace.name

  tags = var.tags
}