# Identity Module - Managed Identity and Role Assignments
# Creates a User Assigned Managed Identity for AKS with least-privilege role assignments

resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}

# AcrPull role assignment - scoped to the specific ACR resource
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# Key Vault Secrets User role assignment - scoped to the specific Key Vault resource
resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}
