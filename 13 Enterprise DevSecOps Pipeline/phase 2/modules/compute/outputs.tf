output "vm_id" {
  description = "The ID of the jumpbox Virtual Machine"
  value       = azurerm_windows_virtual_machine.jumpbox.id
}

output "vm_name" {
  description = "The name of the jumpbox Virtual Machine"
  value       = azurerm_windows_virtual_machine.jumpbox.name
}

output "vm_private_ip" {
  description = "The private IP address of the jumpbox NIC"
  value       = azurerm_network_interface.jumpbox.private_ip_address
}

output "vm_public_ip" {
  description = "The public IP address of the jumpbox"
  value       = azurerm_public_ip.jumpbox.ip_address
}
