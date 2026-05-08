# SEA Hub <-> Spoke
resource "azurerm_virtual_network_peering" "sea_hub_to_spoke" {
  name                         = "peer-hub-sea-to-spoke"
  resource_group_name          = azurerm_resource_group.hub_sea.name
  virtual_network_name         = azurerm_virtual_network.hub_sea.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_sea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "sea_spoke_to_hub" {
  name                         = "peer-spoke-sea-to-hub"
  resource_group_name          = azurerm_resource_group.spoke_sea.name
  virtual_network_name         = azurerm_virtual_network.spoke_sea.name
  remote_virtual_network_id    = azurerm_virtual_network.hub_sea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# EA Hub <-> Spoke
resource "azurerm_virtual_network_peering" "ea_hub_to_spoke" {
  name                         = "peer-hub-ea-to-spoke"
  resource_group_name          = azurerm_resource_group.hub_ea.name
  virtual_network_name         = azurerm_virtual_network.hub_ea.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_ea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "ea_spoke_to_hub" {
  name                         = "peer-spoke-ea-to-hub"
  resource_group_name          = azurerm_resource_group.spoke_ea.name
  virtual_network_name         = azurerm_virtual_network.spoke_ea.name
  remote_virtual_network_id    = azurerm_virtual_network.hub_ea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Hub SEA <-> Hub EA (Global)
resource "azurerm_virtual_network_peering" "hub_sea_to_hub_ea" {
  name                         = "peer-hub-sea-to-hub-ea"
  resource_group_name          = azurerm_resource_group.hub_sea.name
  virtual_network_name         = azurerm_virtual_network.hub_sea.name
  remote_virtual_network_id    = azurerm_virtual_network.hub_ea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [
    azurerm_subnet.hub_sea_fw,
    azurerm_subnet.hub_sea_fw_mgmt,
    azurerm_subnet.hub_sea_mgmt,
    azurerm_subnet_route_table_association.sea_hub_assoc
  ]
}

resource "azurerm_virtual_network_peering" "hub_ea_to_hub_sea" {
  name                         = "peer-hub-ea-to-hub-sea"
  resource_group_name          = azurerm_resource_group.hub_ea.name
  virtual_network_name         = azurerm_virtual_network.hub_ea.name
  remote_virtual_network_id    = azurerm_virtual_network.hub_sea.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [
    azurerm_subnet.hub_ea_fw,
    azurerm_subnet.hub_ea_fw_mgmt,
    azurerm_subnet.hub_ea_mgmt
  ]
}