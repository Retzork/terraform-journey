data "azurerm_subscription" "current" {}

resource "azurerm_user_assigned_identity" "runner_identity" {
  name                = var.uami_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "uami_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.runner_identity.principal_id
}