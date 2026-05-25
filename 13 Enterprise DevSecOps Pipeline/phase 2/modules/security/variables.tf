variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

variable "environment" {
  description = "Environment identifier (e.g., dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project prefix used for resource naming"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID for Key Vault configuration"
  type        = string
  sensitive   = true
}

variable "managed_identity_principal_id" {
  description = "Principal ID of the AKS managed identity for Key Vault Secrets User role assignment. Optional — when empty, the role assignment is handled by the Identity module to avoid circular dependencies."
  type        = string
  sensitive   = true
  default     = ""
}

variable "admin_object_ids" {
  description = "Azure AD object IDs for Key Vault Secrets Officer role assignment (Service Principal, jumpbox MI)"
  type        = list(string)
}

variable "aks_subnet_id" {
  description = "AKS subnet ID for Key Vault network rules (service endpoint access)"
  type        = string
}

variable "management_subnet_id" {
  description = "Management subnet ID for Key Vault network rules (service endpoint access)"
  type        = string
}
