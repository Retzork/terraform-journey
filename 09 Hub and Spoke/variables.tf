variable "location" {
  type        = string
  description = "The Azure region for deployment."
  default     = "southeastasia"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
  default     = "rg-enterprise-networking-sea"
}

variable "hub_vnet_cidr" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "spoke_a_vnet_cidr" {
  type    = list(string)
  default = ["10.1.0.0/16"]
}

variable "spoke_b_vnet_cidr" {
  type    = list(string)
  default = ["10.2.0.0/16"]
}