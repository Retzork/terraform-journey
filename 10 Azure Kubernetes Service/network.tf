resource "azurerm_virtual_network" "aks_vnet" {
  name                = "vnet-aks"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  address_space       = var.vnet_address_space
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = var.aks_subnet_prefix
}