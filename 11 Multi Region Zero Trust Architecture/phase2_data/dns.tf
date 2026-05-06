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