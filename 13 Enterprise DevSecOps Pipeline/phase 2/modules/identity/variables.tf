variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "project_name" {
  description = "Project prefix for naming"
  type        = string
}

variable "acr_id" {
  description = "Azure Container Registry resource ID for AcrPull role assignment"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID for Key Vault Secrets User role assignment"
  type        = string
}
