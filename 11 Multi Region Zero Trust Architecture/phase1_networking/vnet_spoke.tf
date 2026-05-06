resource "azurerm_virtual_network" "spoke_sea" {
  name                = "vnet-spoke-sea"
  location            = azurerm_resource_group.spoke_sea.location
  resource_group_name = azurerm_resource_group.spoke_sea.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_virtual_network" "spoke_ea" {
  name                = "vnet-spoke-ea"
  location            = azurerm_resource_group.spoke_ea.location
  resource_group_name = azurerm_resource_group.spoke_ea.name
  address_space       = ["10.3.0.0/16"]
}