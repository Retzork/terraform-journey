output "runner_vm_name" {
  value       = azurerm_linux_virtual_machine.vm.name
  description = "The name of the self-hosted runner VM"
}

output "managed_identity_client_id" {
  value       = azurerm_user_assigned_identity.runner_identity.client_id
  description = "The client ID of the UAMI (used in pipeline az login --identity)"
}

output "storage_account_name" {
  value       = azurerm_storage_account.tfstate.name
  description = "The storage account used as remote backend by the pipeline"
}

output "tfstate_resource_group" {
  value       = azurerm_resource_group.tfstate.name
  description = "Resource group holding the state storage (separate from workload)"
}
