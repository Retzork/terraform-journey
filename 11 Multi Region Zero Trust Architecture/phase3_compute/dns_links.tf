# Dynamically query the auto-generated Private DNS Zones within the Node Resource Groups
data "azurerm_resources" "aks_sea_dns" {
  resource_group_name = azurerm_kubernetes_cluster.aks_sea.node_resource_group
  type                = "Microsoft.Network/privateDnsZones"
}

data "azurerm_resources" "aks_ea_dns" {
  resource_group_name = azurerm_kubernetes_cluster.aks_ea.node_resource_group
  type                = "Microsoft.Network/privateDnsZones"
}

# Link SEA Hub to both regional AKS DNS zones
resource "azurerm_private_dns_zone_virtual_network_link" "hub_sea_to_aks_sea" {
  name                  = "link-hub-sea-to-aks-sea"
  resource_group_name   = azurerm_kubernetes_cluster.aks_sea.node_resource_group
  private_dns_zone_name = data.azurerm_resources.aks_sea_dns.resources[0].name
  virtual_network_id    = data.azurerm_virtual_network.hub_sea.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_sea_to_aks_ea" {
  name                  = "link-hub-sea-to-aks-ea"
  resource_group_name   = azurerm_kubernetes_cluster.aks_ea.node_resource_group
  private_dns_zone_name = data.azurerm_resources.aks_ea_dns.resources[0].name
  virtual_network_id    = data.azurerm_virtual_network.hub_sea.id
}

# Link EA Hub to both regional AKS DNS zones
resource "azurerm_private_dns_zone_virtual_network_link" "hub_ea_to_aks_sea" {
  name                  = "link-hub-ea-to-aks-sea"
  resource_group_name   = azurerm_kubernetes_cluster.aks_sea.node_resource_group
  private_dns_zone_name = data.azurerm_resources.aks_sea_dns.resources[0].name
  virtual_network_id    = data.azurerm_virtual_network.hub_ea.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_ea_to_aks_ea" {
  name                  = "link-hub-ea-to-aks-ea"
  resource_group_name   = azurerm_kubernetes_cluster.aks_ea.node_resource_group
  private_dns_zone_name = data.azurerm_resources.aks_ea_dns.resources[0].name
  virtual_network_id    = data.azurerm_virtual_network.hub_ea.id
}