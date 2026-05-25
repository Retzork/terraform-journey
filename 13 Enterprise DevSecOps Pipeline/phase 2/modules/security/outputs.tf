output "key_vault_id" {
  description = "The ID of the Azure Key Vault"
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "The name of the Azure Key Vault"
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "The URI of the Azure Key Vault"
  value       = azurerm_key_vault.this.vault_uri
}
