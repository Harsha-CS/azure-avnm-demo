resource "azurerm_network_manager_static_member" "avnm_central_ng_prod_all" {
  for_each = {
    for idx, member in var.members: 
    idx => member
  }
  name = element(split("/",each.value), length(split("/",each.value))-1)
  target_virtual_network_id = each.value
  network_group_id = var.network_group_id
}
