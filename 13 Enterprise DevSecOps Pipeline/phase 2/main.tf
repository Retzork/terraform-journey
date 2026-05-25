# =============================================================================
# Root Module - Phase 2 Infrastructure Composition
# =============================================================================
# Composes all child modules with dependency ordering expressed through
# implicit output-to-input references (no explicit depends_on between modules).
#
# Dependency Order:
#   1. Network (no dependencies)
#   2. ACR + Security (depend on Network outputs)
#   3. Identity (depends on ACR + Security outputs)
#   4. AKS (depends on Network + Identity outputs)
#   5. Compute (depends on Network outputs)
# =============================================================================

# Get current Azure client configuration for tenant_id
data "azurerm_client_config" "current" {}

# =============================================================================
# Resource Group
# =============================================================================

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = merge(var.tags, {
    project     = var.project_name
    environment = var.environment
  })
}

# =============================================================================
# Log Analytics Workspace (required for AKS oms_agent addon)
# =============================================================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = merge(var.tags, {
    project     = var.project_name
    environment = var.environment
  })
}

# =============================================================================
# Module: Network
# =============================================================================

module "network" {
  source = "./modules/network"

  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  environment            = var.environment
  project_name           = var.project_name
  vnet_address_space     = var.vnet_address_space
  aks_subnet_cidr        = var.aks_subnet_cidr
  app_subnet_cidr        = var.app_subnet_cidr
  management_subnet_cidr = var.management_subnet_cidr
}

# =============================================================================
# Module: ACR (depends on Network)
# =============================================================================

module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  project_name        = var.project_name
  acr_sku             = var.acr_sku
  app_subnet_id       = module.network.app_subnet_id
  vnet_id             = module.network.vnet_id
}

# =============================================================================
# Module: Security (depends on Network)
# Note: The Key Vault Secrets User role assignment for the managed identity
# is handled by the Identity module to avoid circular dependencies.
# The security module receives admin_object_ids for Secrets Officer role only.
# =============================================================================

module "security" {
  source = "./modules/security"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  environment          = var.environment
  project_name         = var.project_name
  tenant_id            = data.azurerm_client_config.current.tenant_id
  admin_object_ids     = var.key_vault_admin_object_ids
  aks_subnet_id        = module.network.aks_subnet_id
  management_subnet_id = module.network.management_subnet_id
}

# =============================================================================
# Module: Identity (depends on ACR + Security)
# =============================================================================

module "identity" {
  source = "./modules/identity"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  project_name        = var.project_name
  acr_id              = module.acr.acr_id
  key_vault_id        = module.security.key_vault_id
}

# =============================================================================
# Module: AKS (depends on Network + Identity)
# =============================================================================

module "aks" {
  source = "./modules/aks"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  environment                = var.environment
  project_name               = var.project_name
  aks_subnet_id              = module.network.aks_subnet_id
  managed_identity_id        = module.identity.identity_id
  kubernetes_version         = var.aks_kubernetes_version
  node_count                 = var.aks_node_count
  node_vm_size               = var.aks_node_vm_size
  dns_prefix                 = var.aks_dns_prefix
  api_authorized_ip_ranges   = var.aks_api_authorized_ips
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# =============================================================================
# Module: Compute (depends on Network)
# =============================================================================

module "compute" {
  source = "./modules/compute"

  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  environment            = var.environment
  project_name           = var.project_name
  management_subnet_id   = module.network.management_subnet_id
  management_nsg_id      = module.network.management_nsg_id
  vm_size                = var.vm_size
  admin_username         = var.vm_admin_username
  admin_password         = var.vm_admin_password
  allowed_rdp_source_ips = var.allowed_rdp_source_ips
}
