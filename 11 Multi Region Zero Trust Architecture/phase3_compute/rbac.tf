# RBAC for East Asia AKS
resource "azurerm_role_assignment" "aks_ea_network" {
  scope                = azurerm_virtual_network.spoke_ea.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_ea.kubelet_identity[0].object_id
}

# RBAC for Southeast Asia AKS
resource "azurerm_role_assignment" "aks_sea_network" {
  scope                = azurerm_virtual_network.spoke_sea.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_sea.kubelet_identity[0].object_id
}