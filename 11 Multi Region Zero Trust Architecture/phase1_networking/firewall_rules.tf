# SEA Updated Rules
resource "azurerm_firewall_network_rule_collection" "sea_aks_net" {
  name                = "aks-network-rules"
  azure_firewall_name = azurerm_firewall.fw_sea.name
  resource_group_name = azurerm_resource_group.hub_sea.name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "allow-dns"
    source_addresses      = ["10.1.0.0/16"]
    destination_ports     = ["53"]
    destination_addresses = ["168.63.129.16"]
    protocols             = ["UDP", "TCP"]
  }

  rule {
    name                  = "allow-ntp"
    source_addresses      = ["10.1.0.0/16"]
    destination_ports     = ["123"]
    destination_addresses = ["*"]
    protocols             = ["UDP"]
  }

  rule {
    name                  = "allow-tunnel"
    source_addresses      = ["10.1.0.0/16"]
    destination_ports     = ["9000", "1194", "22"]
    destination_addresses = ["AzureCloud"]
    protocols             = ["TCP"]
  }

  rule {
    name                  = "allow-https-cloud"
    source_addresses      = ["10.1.0.0/16"]
    destination_ports     = ["443"]
    destination_addresses = ["AzureCloud", "MicrosoftContainerRegistry"]
    protocols             = ["TCP"]
  }
}

resource "azurerm_firewall_application_rule_collection" "sea_aks_app" {
  name                = "aks-app-rules"
  azure_firewall_name = azurerm_firewall.fw_sea.name
  resource_group_name = azurerm_resource_group.hub_sea.name
  priority            = 100
  action              = "Allow"

  rule {
    name             = "allow-essential-fqdns"
    source_addresses = ["10.1.0.0/16"]
    target_fqdns     = [
      "*.hcp.${var.region1}.azmk8s.io",
      "mcr.microsoft.com",
      "*.data.mcr.microsoft.com",
      "management.azure.com",
      "login.microsoftonline.com",
      "packages.microsoft.com",
      "acs-mirror.azureedge.net",
      "*.ubuntu.com",
      "archive.ubuntu.com",
      "security.ubuntu.com"
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }
}

# EA Updated Rules
resource "azurerm_firewall_network_rule_collection" "ea_aks_net" {
  name                = "aks-network-rules"
  azure_firewall_name = azurerm_firewall.fw_ea.name
  resource_group_name = azurerm_resource_group.hub_ea.name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "allow-dns"
    source_addresses      = ["10.3.0.0/16"]
    destination_ports     = ["53"]
    destination_addresses = ["168.63.129.16"]
    protocols             = ["UDP", "TCP"]
  }

  rule {
    name                  = "allow-ntp"
    source_addresses      = ["10.3.0.0/16"]
    destination_ports     = ["123"]
    destination_addresses = ["*"]
    protocols             = ["UDP"]
  }

  rule {
    name                  = "allow-tunnel"
    source_addresses      = ["10.3.0.0/16"]
    destination_ports     = ["9000", "1194", "22"]
    destination_addresses = ["AzureCloud"]
    protocols             = ["TCP"]
  }

  rule {
    name                  = "allow-https-cloud"
    source_addresses      = ["10.3.0.0/16"]
    destination_ports     = ["443"]
    destination_addresses = ["AzureCloud", "MicrosoftContainerRegistry"]
    protocols             = ["TCP"]
  }
}

resource "azurerm_firewall_application_rule_collection" "ea_aks_app" {
  name                = "aks-app-rules"
  azure_firewall_name = azurerm_firewall.fw_ea.name
  resource_group_name = azurerm_resource_group.hub_ea.name
  priority            = 100
  action              = "Allow"

  rule {
    name             = "allow-essential-fqdns"
    source_addresses = ["10.3.0.0/16"]
    target_fqdns     = [
      "*.hcp.${var.region2}.azmk8s.io",
      "mcr.microsoft.com",
      "*.data.mcr.microsoft.com",
      "management.azure.com",
      "login.microsoftonline.com",
      "packages.microsoft.com",
      "acs-mirror.azureedge.net",
      "*.ubuntu.com",
      "archive.ubuntu.com",
      "security.ubuntu.com"
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }
}