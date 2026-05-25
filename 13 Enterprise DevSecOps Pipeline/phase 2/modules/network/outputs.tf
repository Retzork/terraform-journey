output "vnet_id" {
  description = "The ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "The name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "The ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "app_subnet_id" {
  description = "The ID of the application subnet"
  value       = azurerm_subnet.app.id
}

output "management_subnet_id" {
  description = "The ID of the management subnet"
  value       = azurerm_subnet.mgmt.id
}

output "aks_nsg_id" {
  description = "The ID of the AKS subnet Network Security Group"
  value       = azurerm_network_security_group.aks.id
}

output "app_nsg_id" {
  description = "The ID of the application subnet Network Security Group"
  value       = azurerm_network_security_group.app.id
}

output "management_nsg_id" {
  description = "The ID of the management subnet Network Security Group"
  value       = azurerm_network_security_group.mgmt.id
}
