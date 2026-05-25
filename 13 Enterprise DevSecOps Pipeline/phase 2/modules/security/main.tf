# Security Module - Azure Key Vault with RBAC authorization
# Provides centralized secrets management with least-privilege access control

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                = "kv-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  # RBAC authorization mode (not access policies)
  rbac_authorization_enabled = true

  # Soft delete with 90-day retention
  soft_delete_retention_days = 90

  # Purge protection enabled
  purge_protection_enabled = true

  # Disable public network access
  public_network_access_enabled = false

  # Network rules - allow access only from VNet subnets
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.aks_subnet_id, var.management_subnet_id]
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}

# Assign "Key Vault Secrets User" role to AKS Managed Identity (scoped to Key Vault)
# Note: This is conditionally created only when managed_identity_principal_id is provided.
# When using the Identity module (which already assigns this role), pass no value to avoid
# circular dependencies between Security and Identity modules.
resource "azurerm_role_assignment" "kv_secrets_user_aks" {
  count                = var.managed_identity_principal_id != "" ? 1 : 0
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.managed_identity_principal_id
}

# Assign "Key Vault Secrets Officer" role to admin identities (scoped to Key Vault)
resource "azurerm_role_assignment" "kv_secrets_officer_admin" {
  count                = length(var.admin_object_ids)
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.admin_object_ids[count.index]
}
