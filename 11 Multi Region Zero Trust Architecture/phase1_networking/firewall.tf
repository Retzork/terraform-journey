# Public IPs for Data Plane
resource "azurerm_public_ip" "fw_sea_pip" {
  name                = "pip-fw-sea"
  location            = azurerm_resource_group.hub_sea.location
  resource_group_name = azurerm_resource_group.hub_sea.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "fw_ea_pip" {
  name                = "pip-fw-ea"
  location            = azurerm_resource_group.hub_ea.location
  resource_group_name = azurerm_resource_group.hub_ea.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Public IPs for Management Plane (Mandatory for Basic SKU)
resource "azurerm_public_ip" "fw_sea_mgmt_pip" {
  name                = "pip-fw-sea-mgmt"
  location            = azurerm_resource_group.hub_sea.location
  resource_group_name = azurerm_resource_group.hub_sea.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "fw_ea_mgmt_pip" {
  name                = "pip-fw-ea-mgmt"
  location            = azurerm_resource_group.hub_ea.location
  resource_group_name = azurerm_resource_group.hub_ea.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure Firewalls (Basic SKU)
resource "azurerm_firewall" "fw_sea" {
  name                = "fw-hub-sea"
  location            = azurerm_resource_group.hub_sea.location
  resource_group_name = azurerm_resource_group.hub_sea.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub_sea_fw.id
    public_ip_address_id = azurerm_public_ip.fw_sea_pip.id
  }

  management_ip_configuration {
    name                 = "mgmt-configuration"
    subnet_id            = azurerm_subnet.hub_sea_fw_mgmt.id
    public_ip_address_id = azurerm_public_ip.fw_sea_mgmt_pip.id
  }
}

resource "azurerm_firewall" "fw_ea" {
  name                = "fw-hub-ea"
  location            = azurerm_resource_group.hub_ea.location
  resource_group_name = azurerm_resource_group.hub_ea.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub_ea_fw.id
    public_ip_address_id = azurerm_public_ip.fw_ea_pip.id
  }

  management_ip_configuration {
    name                 = "mgmt-configuration"
    subnet_id            = azurerm_subnet.hub_ea_fw_mgmt.id
    public_ip_address_id = azurerm_public_ip.fw_ea_mgmt_pip.id
  }
}