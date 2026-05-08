# Southeast Asia
resource "azurerm_virtual_network" "hub_sea" {
  name                = "vnet-hub-sea"
  location            = azurerm_resource_group.hub_sea.location
  resource_group_name = azurerm_resource_group.hub_sea.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_virtual_network" "spoke_sea" {
  name                = "vnet-spoke-sea"
  location            = azurerm_resource_group.spoke_sea.location
  resource_group_name = azurerm_resource_group.spoke_sea.name
  address_space       = ["10.1.0.0/16"]
}

# East Asia
resource "azurerm_virtual_network" "hub_ea" {
  name                = "vnet-hub-ea"
  location            = azurerm_resource_group.hub_ea.location
  resource_group_name = azurerm_resource_group.hub_ea.name
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_virtual_network" "spoke_ea" {
  name                = "vnet-spoke-ea"
  location            = azurerm_resource_group.spoke_ea.location
  resource_group_name = azurerm_resource_group.spoke_ea.name
  address_space       = ["10.3.0.0/16"]
}