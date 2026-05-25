output "identity_id" {
  description = "The full resource ID of the User Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.aks.id
}

output "principal_id" {
  description = "The principal ID of the User Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.aks.principal_id
}

output "client_id" {
  description = "The client ID of the User Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.aks.client_id
}
