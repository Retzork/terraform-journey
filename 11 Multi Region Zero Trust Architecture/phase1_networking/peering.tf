# Local Peering: SEA Hub <-> SEA Spoke
resource "azurerm_virtual_network_peering" "hub_to_spoke_sea" {
  name                         = "peer-hub-to-spoke-sea"
  resource_group_name          = azurerm_resource_group.hub_sea.name
  virtual_network_name         = azurerm_virtual_network.hub_sea.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_sea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub_sea" {
  name                         = "peer-spoke-to-hub-sea"
  resource_group_name          = azurerm_resource_group.spoke_sea.name
  virtual_network_name         = azurerm_virtual_network.spoke_sea.name
  remote_virtual_network_id    = azurerm_virtual_network.hub_sea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Local Peering: EA Hub <-> EA Spoke
resource "azurerm_virtual_network_peering" "hub_to_spoke_ea" {
  name                         = "peer-hub-to-spoke-ea"
  resource_group_name          = azurerm_resource_group.hub_ea.name
  virtual_network_name         = azurerm_virtual_network.hub_ea.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_ea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub_ea" {
  name                         = "peer-spoke-to-hub-ea"
  resource_group_name          = azurerm_resource_group.spoke_ea.name
  virtual_network_name         = azurerm_virtual_network.spoke_ea.name
  remote_virtual_network_id    = azurerm_virtual_network.hub_ea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Global Peering: SEA Hub <-> EA Hub
resource "azurerm_virtual_network_peering" "hub_sea_to_hub_ea" {
  name                         = "peer-hub-sea-to-hub-ea"
  resource_group_name          = azurerm_resource_group.hub_sea.name
  virtual_network_name         = azurerm_virtual_network.hub_sea.name
  remote_virtual_network_id    = azurerm_virtual_network.hub_ea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "hub_ea_to_hub_sea" {
  name                         = "peer-hub-ea-to-hub-sea"
  resource_group_name          = azurerm_resource_group.hub_ea.name
  virtual_network_name         = azurerm_virtual_network.hub_ea.name
  remote_virtual_network_id    = azurerm_virtual_network.hub_sea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}