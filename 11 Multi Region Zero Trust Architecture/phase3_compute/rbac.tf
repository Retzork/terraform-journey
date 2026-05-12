data "azurerm_virtual_network" "spoke_ea" {
  name                = "vnet-spoke-ea"
  resource_group_name = data.azurerm_resource_group.spoke_ea.name
}

data "azurerm_virtual_network" "spoke_sea" {
  name                = "vnet-spoke-sea"
  resource_group_name = data.azurerm_resource_group.spoke_sea.name
}

resource "azurerm_role_assignment" "aks_ea_network" {
  scope                = data.azurerm_virtual_network.spoke_ea.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_ea.identity[0].principal_id
}

resource "azurerm_role_assignment" "aks_sea_network" {
  scope                = data.azurerm_virtual_network.spoke_sea.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_sea.identity[0].principal_id
}