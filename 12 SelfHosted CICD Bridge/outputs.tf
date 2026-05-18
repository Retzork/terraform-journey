output "web_app_url" {
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
  description = "The URL of the deployed web app"
}

output "web_app_name" {
  value       = azurerm_linux_web_app.app.name
  description = "The name of the web app"
}

output "runner_vm_name" {
  value       = azurerm_linux_virtual_machine.vm.name
  description = "The name of the self-hosted runner VM"
}

output "managed_identity_client_id" {
  value       = azurerm_user_assigned_identity.runner_identity.client_id
  description = "The client ID of the UAMI (used in az login --identity)"
}

output "storage_account_name" {
  value       = azurerm_storage_account.tfstate.name
  description = "The storage account holding remote state"
}
