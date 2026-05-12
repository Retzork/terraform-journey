resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.database.windows.net"
  resource_group_name = data.azurerm_resource_group.hub_sea.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sea_link" {
  name                  = "dns-link-sea"
  resource_group_name   = data.azurerm_resource_group.hub_sea.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = data.azurerm_virtual_network.hub_sea.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "ea_link" {
  name                  = "dns-link-ea"
  resource_group_name   = data.azurerm_resource_group.hub_sea.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = data.azurerm_virtual_network.hub_ea.id
}

# Spoke VNet links - required for AKS pods to resolve SQL private endpoints
data "azurerm_virtual_network" "spoke_sea" {
  name                = "vnet-spoke-sea"
  resource_group_name = "rg-spoke-sea"
}

data "azurerm_virtual_network" "spoke_ea" {
  name                = "vnet-spoke-ea"
  resource_group_name = "rg-spoke-ea"
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke_sea_link" {
  name                  = "dns-link-spoke-sea"
  resource_group_name   = data.azurerm_resource_group.hub_sea.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = data.azurerm_virtual_network.spoke_sea.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke_ea_link" {
  name                  = "dns-link-spoke-ea"
  resource_group_name   = data.azurerm_resource_group.hub_sea.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = data.azurerm_virtual_network.spoke_ea.id
}