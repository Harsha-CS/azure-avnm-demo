resource "azurerm_virtual_network" "vnet" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  address_space = var.address_space_vnet
  dns_servers   = var.dns_servers

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag-base" {
  name                       = "diag-base"
  target_resource_id         = azurerm_virtual_network.vnet.id
  log_analytics_workspace_id = var.law_resource_id

  enabled_log {
    category = "VMProtectionAlerts"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_subnet" "subnet" {

  for_each = {
    for subnet in var.subnets :
    subnet.name => subnet
  }

  name                                          = each.value.name
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  address_prefixes                              = each.value.address_prefixes
  private_endpoint_network_policies_enabled     = local.enable_private_endpoint_network_policies
  private_link_service_network_policies_enabled = local.enable_private_link_service_network_policies
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  depends_on = [ azurerm_subnet.subnet ]
  for_each = {
    for subnet in var.subnets :
    subnet.name => subnet
  }


  subnet_id                 = "${azurerm_virtual_network.vnet.id}/subnets/${each.value.name}"
  network_security_group_id = each.value.network_security_group_id
}

# Pause and wait for virtual network information to replication through ARM API
resource "time_sleep" "wait_10_seconds" {
  depends_on = [azurerm_subnet.subnet]
  create_duration = "10s"
}
