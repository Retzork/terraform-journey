# Data sources to find the auto-generated AKS DNS zones
data "azurerm_private_dns_zone" "aks_sea_dns" {
  name                = "69b7b64c-f0fc-42f3-84a2-ac3f993ef8dd.privatelink.southeastasia.azmk8s.io"
  resource_group_name = "mc_rg-spoke-sea_aks-spoke-sea_southeastasia"
}

data "azurerm_private_dns_zone" "aks_ea_dns" {
  name                = "cc8d4456-bbaa-4d1b-a0ed-f24879dab66f.privatelink.eastasia.azmk8s.io"
  resource_group_name = "mc_rg-spoke-ea_aks-spoke-ea_eastasia"
}

# Link SEA Hub to both regional AKS DNS zones
resource "azurerm_private_dns_zone_virtual_network_link" "hub_sea_to_aks_sea" {
  name                  = "link-hub-sea-to-aks-sea"
  resource_group_name   = data.azurerm_private_dns_zone.aks_sea_dns.resource_group_name
  private_dns_zone_name = data.azurerm_private_dns_zone.aks_sea_dns.name
  virtual_network_id    = data.azurerm_virtual_network.hub_sea.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_sea_to_aks_ea" {
  name                  = "link-hub-sea-to-aks-ea"
  resource_group_name   = data.azurerm_private_dns_zone.aks_ea_dns.resource_group_name
  private_dns_zone_name = data.azurerm_private_dns_zone.aks_ea_dns.name
  virtual_network_id    = data.azurerm_virtual_network.hub_sea.id
}

# Link EA Hub to both regional AKS DNS zones
resource "azurerm_private_dns_zone_virtual_network_link" "hub_ea_to_aks_sea" {
  name                  = "link-hub-ea-to-aks-sea"
  resource_group_name   = data.azurerm_private_dns_zone.aks_sea_dns.resource_group_name
  private_dns_zone_name = data.azurerm_private_dns_zone.aks_sea_dns.name
  virtual_network_id    = data.azurerm_virtual_network.hub_ea.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_ea_to_aks_ea" {
  name                  = "link-hub-ea-to-aks-ea"
  resource_group_name   = data.azurerm_private_dns_zone.aks_ea_dns.resource_group_name
  private_dns_zone_name = data.azurerm_private_dns_zone.aks_ea_dns.name
  virtual_network_id    = data.azurerm_virtual_network.hub_ea.id
}