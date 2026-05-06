resource "azurerm_resource_group" "hub_sea" {
  name     = "rg-hub-sea"
  location = var.region1
}

resource "azurerm_resource_group" "spoke_sea" {
  name     = "rg-spoke-sea"
  location = var.region1
}

resource "azurerm_resource_group" "hub_ea" {
  name     = "rg-hub-ea"
  location = var.region2
}

resource "azurerm_resource_group" "spoke_ea" {
  name     = "rg-spoke-ea"
  location = var.region2
}