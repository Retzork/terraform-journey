# -----------------------------------------------------------------------------
# AKS Module Outputs
# -----------------------------------------------------------------------------

output "cluster_id" {
  description = "The ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "kube_config" {
  description = "The raw kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "cluster_fqdn" {
  description = "The FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "node_resource_group" {
  description = "The name of the auto-generated resource group for AKS node pool resources"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}
