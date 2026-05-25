variable "resource_group_name" {
  description = "Name of the resource group where network resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region for all network resources"
  type        = string
}

variable "environment" {
  description = "Environment identifier (e.g., dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project prefix used in resource naming conventions"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network (e.g., [\"10.0.0.0/16\"])"
  type        = list(string)
}

variable "aks_subnet_cidr" {
  description = "CIDR block for the AKS subnet (e.g., 10.0.1.0/24)"
  type        = string

  validation {
    condition     = can(cidrhost(var.aks_subnet_cidr, 0))
    error_message = "The aks_subnet_cidr must be a valid CIDR notation (e.g., 10.0.1.0/24)."
  }
}

variable "app_subnet_cidr" {
  description = "CIDR block for the application subnet (e.g., 10.0.2.0/24)"
  type        = string

  validation {
    condition     = can(cidrhost(var.app_subnet_cidr, 0))
    error_message = "The app_subnet_cidr must be a valid CIDR notation (e.g., 10.0.2.0/24)."
  }
}

variable "management_subnet_cidr" {
  description = "CIDR block for the management subnet (e.g., 10.0.3.0/24)"
  type        = string

  validation {
    condition     = can(cidrhost(var.management_subnet_cidr, 0))
    error_message = "The management_subnet_cidr must be a valid CIDR notation (e.g., 10.0.3.0/24)."
  }
}
