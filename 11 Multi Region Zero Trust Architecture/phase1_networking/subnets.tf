# SEA Hub Subnets
resource "azurerm_subnet" "hub_sea_fw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub_sea.name
  virtual_network_name = azurerm_virtual_network.hub_sea.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "hub_sea_fw_mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.hub_sea.name
  virtual_network_name = azurerm_virtual_network.hub_sea.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "hub_sea_mgmt" {
  name                 = "snet-mgmt-sea"
  resource_group_name  = azurerm_resource_group.hub_sea.name
  virtual_network_name = azurerm_virtual_network.hub_sea.name
  address_prefixes     = ["10.0.4.0/24"]
}

# EA Hub Subnets
resource "azurerm_subnet" "hub_ea_fw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub_ea.name
  virtual_network_name = azurerm_virtual_network.hub_ea.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_subnet" "hub_ea_fw_mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.hub_ea.name
  virtual_network_name = azurerm_virtual_network.hub_ea.name
  address_prefixes     = ["10.2.3.0/24"]
}

resource "azurerm_subnet" "hub_ea_mgmt" {
  name                 = "snet-mgmt-ea"
  resource_group_name  = azurerm_resource_group.hub_ea.name
  virtual_network_name = azurerm_virtual_network.hub_ea.name
  address_prefixes     = ["10.2.4.0/24"]
}

# Spoke Subnets
resource "azurerm_subnet" "spoke_sea_workload" {
  name                 = "snet-workload-sea"
  resource_group_name  = azurerm_resource_group.spoke_sea.name
  virtual_network_name = azurerm_virtual_network.spoke_sea.name
  private_link_service_network_policies_enabled = false
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "spoke_ea_workload" {
  name                 = "snet-workload-ea"
  resource_group_name  = azurerm_resource_group.spoke_ea.name
  virtual_network_name = azurerm_virtual_network.spoke_ea.name
  private_link_service_network_policies_enabled = false
  address_prefixes     = ["10.3.1.0/24"]
}