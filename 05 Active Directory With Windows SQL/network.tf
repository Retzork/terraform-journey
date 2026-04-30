resource "azurerm_resource_group" "ad_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "ad_vnet" {
  name                = "ad-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  dns_servers         = ["10.0.1.4"] # Global VNet DNS assigned to the DC
}

resource "azurerm_subnet" "ad_subnet" {
  name                 = "ad-subnet"
  resource_group_name  = azurerm_resource_group.ad_rg.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}