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

variable "acr_sku" {
  description = "SKU for Azure Container Registry (Premium required for private endpoint)"
  type        = string
  default     = "Premium"
}

variable "app_subnet_id" {
  description = "Subnet ID for the ACR private endpoint (application subnet)"
  type        = string
}

variable "vnet_id" {
  description = "VNet ID for private DNS zone virtual network link"
  type        = string
}
