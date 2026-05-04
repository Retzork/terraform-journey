resource "azurerm_public_ip" "fw_pip" {
  name                = "pip-firewall"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "fw_policy" {
  name                = "fw-policy-hub"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku                 = "Standard"
}

resource "azurerm_firewall" "hub_fw" {
  name                = "fw-hub"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.fw_policy.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "lab_rules" {
  name               = "rg-firewall-rules"
  firewall_policy_id = azurerm_firewall_policy.fw_policy.id
  priority           = 100

  network_rule_collection {
    name     = "internal-traffic"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "allow-spoke-to-spoke-icmp"
      protocols             = ["ICMP"]
      source_addresses      = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_addresses = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_ports     = ["*"]
    }
    rule {
      name                  = "allow-spoke-to-spoke-ssh"
      protocols             = ["TCP"]
      source_addresses      = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_addresses = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_ports     = ["22"]
    }
  }

  application_rule_collection {
    name     = "egress-traffic"
    priority = 300
    action   = "Allow"
    rule {
      name = "allow-ubuntu-updates"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["10.1.0.0/16", "10.2.0.0/16"]
      destination_fqdns = ["*.ubuntu.com", "azure.archive.ubuntu.com"]
    }
  }
}