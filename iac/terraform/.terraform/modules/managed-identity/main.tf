resource "azurerm_user_assigned_identity" "umi" {
  location            = var.location
  name                = var.name
  resource_group_name = var.resource_group_name

  tags = var.tags

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}



