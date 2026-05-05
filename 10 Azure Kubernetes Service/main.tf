terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "azurerm" {
  features {}
}

# Provider configurations set for local state and kubeconfig execution
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks_cluster.kube_admin_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_admin_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks_cluster.kube_admin_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_admin_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_admin_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_admin_config.0.cluster_ca_certificate)
  }
}
resource "azurerm_resource_group" "aks_rg" {
  name     = var.resource_group_name
  location = var.location
}