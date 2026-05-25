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

variable "aks_subnet_id" {
  description = "Subnet ID for AKS nodes"
  type        = string
}

variable "managed_identity_id" {
  description = "User Assigned Managed Identity resource ID"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for the default node pool nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "api_authorized_ip_ranges" {
  description = "IP ranges authorized to access the AKS API server"
  type        = list(string)
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for monitoring (oms_agent addon)"
  type        = string
}
