variable "environment" {
  description = "Environment identifier used in resource naming (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "southeastasia"
}

variable "project_name" {
  description = "Project prefix used in resource naming conventions"
  type        = string
  default     = "devsecops"
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_cidr" {
  description = "CIDR range for the AKS node subnet (snet-aks)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_subnet_cidr" {
  description = "CIDR range for the application subnet (snet-app)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "management_subnet_cidr" {
  description = "CIDR range for the management subnet (snet-mgmt)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.28"
}

variable "aks_node_count" {
  description = "Number of nodes in the AKS default node pool"
  type        = number
  default     = 2
}

variable "aks_node_vm_size" {
  description = "VM size for AKS default node pool nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "devsecops-aks"
}

variable "acr_sku" {
  description = "SKU for the Azure Container Registry (Premium required for private endpoint)"
  type        = string
  default     = "Premium"
}

variable "vm_size" {
  description = "VM size for the jumpbox virtual machine"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "vm_admin_username" {
  description = "Admin username for the jumpbox VM"
  type        = string
  default     = "azureadmin"
}

variable "vm_admin_password" {
  description = "Admin password for the jumpbox VM. Set via TF_VAR_vm_admin_password environment variable."
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.vm_admin_password) >= 12 &&
      can(regex("[A-Z]", var.vm_admin_password)) &&
      can(regex("[a-z]", var.vm_admin_password)) &&
      can(regex("[0-9]", var.vm_admin_password)) &&
      can(regex("[^a-zA-Z0-9]", var.vm_admin_password))
    )
    error_message = "Password must be at least 12 characters and contain at least one uppercase letter, one lowercase letter, one digit, and one special character."
  }
}

variable "allowed_rdp_source_ips" {
  description = "List of IP addresses allowed to RDP to the jumpbox (CIDR notation)"
  type        = list(string)
}

variable "aks_api_authorized_ips" {
  description = "List of IP ranges authorized to access the AKS API server (CIDR notation)"
  type        = list(string)
}

variable "key_vault_admin_object_ids" {
  description = "List of Azure AD object IDs with Key Vault Secrets Officer access"
  type        = list(string)
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
