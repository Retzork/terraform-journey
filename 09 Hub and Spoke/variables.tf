variable "location" {
  type        = string
  description = "The Azure region for deployment."
  default     = "southeastasia"
}

variable "rg_name" {
  type    = string
  default = "rg-hubspoke-lab-sea"
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

variable "admin_username" {
  type    = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}