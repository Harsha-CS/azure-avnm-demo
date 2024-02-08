# Create the network security group
resource "azurerm_network_security_group" "nsg" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag-base" {
  name                       = "diag-base"
  target_resource_id         = azurerm_network_security_group.nsg.id
  log_analytics_workspace_id = var.law_resource_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# Create security group rules
resource "azurerm_network_security_rule" "rule" {
  for_each = {
    for rule in var.security_rules :
    rule.name => rule
  }
  name                         = each.value.name
  description                  = each.value.description
  priority                     = each.value.priority
  direction                    = each.value.direction
  access                       = each.value.access
  protocol                     = each.value.protocol
  source_port_range            = each.value.source_port_range
  source_port_ranges           = each.value.source_port_ranges
  destination_port_range       = each.value.destination_port_range
  destination_port_ranges      = each.value.destination_port_ranges
  source_address_prefix        = each.value.source_address_prefix
  source_address_prefixes      = each.value.source_address_prefixes
  destination_address_prefix   = each.value.destination_address_prefix
  destination_address_prefixes = each.value.destination_address_prefixes
  resource_group_name          = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg.name
}

# Create the flow log and enable traffic analytics
resource "azurerm_network_watcher_flow_log" "flow_log" {
  name                      = "${var.name}fl"
  location                  = var.location
  resource_group_name       = var.network_watcher_resource_group_name
  enabled                   = local.flow_logs_enabled
  network_watcher_name      = var.network_watcher_name
  network_security_group_id = azurerm_network_security_group.nsg.id
  storage_account_id        = var.flowLogStorageAccountId
  retention_policy {
    enabled = local.flow_logs_retention_policy_enabled
    days    = local.flow_logs_retention_days
  }
  traffic_analytics {
    enabled               = local.traffic_analytics_enabled
    workspace_region      = var.trafficAnalyticsWorkspaceRegion
    workspace_id          = var.trafficAnalyticsWorkspaceGuid
    workspace_resource_id = var.trafficAnalyticsWorkspaceId
    interval_in_minutes   = local.traffic_analytics_interval_in_minutes
  }
}
