# Root Module Outputs
# These outputs expose key resource identifiers consumed by Phase 3/4

# --- AKS Cluster Outputs ---

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster"
  value       = module.aks.cluster_id
}

output "aks_kube_config" {
  description = "Kubeconfig for the AKS cluster (sensitive)"
  value       = module.aks.kube_config
  sensitive   = true
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster API server"
  value       = module.aks.cluster_fqdn
}

# --- ACR Outputs ---

output "acr_login_server" {
  description = "Login server URL for the Azure Container Registry"
  value       = module.acr.acr_login_server
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.acr.acr_name
}

# --- Key Vault Outputs ---

output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = module.security.key_vault_name
}

output "key_vault_id" {
  description = "Resource ID of the Azure Key Vault"
  value       = module.security.key_vault_id
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = module.security.key_vault_uri
}

# --- Network Outputs ---

output "vnet_id" {
  description = "Resource ID of the Virtual Network"
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = module.network.vnet_name
}

# --- Compute Outputs ---

output "jumpbox_public_ip" {
  description = "Public IP address of the jumpbox VM"
  value       = module.compute.vm_public_ip
}

output "jumpbox_private_ip" {
  description = "Private IP address of the jumpbox VM"
  value       = module.compute.vm_private_ip
}

# --- Identity Outputs ---

output "managed_identity_client_id" {
  description = "Client ID of the AKS User Assigned Managed Identity"
  value       = module.identity.client_id
}

# --- Resource Group Output ---

output "resource_group_name" {
  description = "Name of the resource group containing all Phase 2 resources"
  value       = azurerm_resource_group.main.name
}
