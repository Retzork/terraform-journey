resource "azurerm_resource_group" "network_rg" {
  name     = var.resource_group_name
  location = var.location
}

# Hub Virtual Network
resource "azurerm_virtual_network" "hub_vnet" {
  name                = "vnet-hub-sea"
  address_space       = var.hub_vnet_cidr
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
}

resource "azurerm_subnet" "firewall_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.0.0.64/27"]
}

# Spoke A Virtual Network
resource "azurerm_virtual_network" "spoke_a_vnet" {
  name                = "vnet-spoke-a-sea"
  address_space       = var.spoke_a_vnet_cidr
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
}

resource "azurerm_subnet" "spoke_a_workload" {
  name                 = "snet-workload-a"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_a_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Spoke B Virtual Network
resource "azurerm_virtual_network" "spoke_b_vnet" {
  name                = "vnet-spoke-b-sea"
  address_space       = var.spoke_b_vnet_cidr
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
}

resource "azurerm_subnet" "spoke_b_workload" {
  name                 = "snet-workload-b"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_b_vnet.name
  address_prefixes     = ["10.2.1.0/24"]
}