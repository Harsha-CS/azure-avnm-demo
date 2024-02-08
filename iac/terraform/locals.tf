locals {
    required_tags = {
        created_date = timestamp()
        created_by   = data.azurerm_client_config.identity_config.object_id
        modified_date = timestamp()
        modified_by   = data.azurerm_client_config.identity_config.object_id
    }
    tags = merge(
        var.tags,
        local.required_tags
    )
}