data "azurerm_resource_group" "hub_sea" {
  name = "rg-hub-sea"
}

data "azurerm_resource_group" "hub_ea" {
  name = "rg-hub-ea"
}

data "azurerm_virtual_network" "hub_sea" {
  name                = "vnet-hub-sea"
  resource_group_name = "rg-hub-sea"
}

data "azurerm_virtual_network" "hub_ea" {
  name                = "vnet-hub-ea"
  resource_group_name = "rg-hub-ea"
}

data "azurerm_subnet" "sea_workload" {
  name                 = "snet-workload-sea"
  virtual_network_name = "vnet-spoke-sea"
  resource_group_name  = "rg-spoke-sea"
}

data "azurerm_subnet" "ea_workload" {
  name                 = "snet-workload-ea"
  virtual_network_name = "vnet-spoke-ea"
  resource_group_name  = "rg-spoke-ea"
}