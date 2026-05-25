# Azure Container Registry with Private Endpoint
# Requirements: 3.1, 3.2, 3.3, 3.4, 10.2, 10.3

locals {
  # ACR naming: alphanumeric only, no hyphens (Azure constraint)
  acr_name = "acr${var.project_name}${var.environment}"

  # Standard naming for other resources
  private_endpoint_name = "pe-acr-${var.project_name}-${var.environment}"
  dns_zone_name         = "privatelink.azurecr.io"
  vnet_link_name        = "vnetlink-acr-${var.project_name}-${var.environment}"

  # Mandatory tags applied to all resources
  tags = {
    project     = var.project_name
    environment = var.environment
  }
}

# Azure Container Registry - Premium SKU with private access only
resource "azurerm_container_registry" "this" {
  name                          = local.acr_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.acr_sku
  admin_enabled                 = false
  public_network_access_enabled = false

  tags = local.tags
}

# Private DNS Zone for ACR private endpoint name resolution
resource "azurerm_private_dns_zone" "acr" {
  name                = local.dns_zone_name
  resource_group_name = var.resource_group_name

  tags = local.tags
}

# Link Private DNS Zone to VNet for name resolution from within the network
resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = local.vnet_link_name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = local.tags
}

# Private Endpoint for ACR in the application subnet
resource "azurerm_private_endpoint" "acr" {
  name                = local.private_endpoint_name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.app_subnet_id

  private_service_connection {
    name                           = "psc-acr-${var.project_name}-${var.environment}"
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }

  tags = local.tags
}
