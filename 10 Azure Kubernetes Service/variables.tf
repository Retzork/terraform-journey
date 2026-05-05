variable "location" {
  type        = string
  description = "Azure region for resource deployment"
  default     = "southeastasia"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
  default     = "rg-aks-foundation"
}

variable "vnet_address_space" {
  type        = list(string)
  description = "Address space for the Virtual Network"
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_prefix" {
  type        = list(string)
  description = "Subnet prefix for the AKS cluster"
  default     = ["10.0.0.0/22"]
}