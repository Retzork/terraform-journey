variable "subscription_id" {
  type        = string
  description = "The target Azure Subscription ID"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the existing Resource Group"
  default     = "dummyRG"
  #default     = "value" #input
}

variable "vnet_name" {
  type        = string
  description = "Name of the existing Virtual Network"
  default     = "dummyVNet"
  #default     = "value" #input
}

variable "subnet_name" {
  type        = string
  description = "Name of the existing Subnet for the Hub VM"
  default     = "dummySubnet"
  #default     = "value" #input
}

variable "admin_username" {
  type        = string
  description = "Admin username for the Linux Hub VM"
}

variable "admin_password" {
  type        = string
  description = "Password for the Linux Hub VM"
  sensitive   = true
}

variable "admin_ip_address" {
  type        = string
  description = "Your public IP address to restrict Grafana access [e.g., 203.0.113.1/32]"
}

variable "grafana_admin_user" {
  type        = string
  description = "Custom username for Grafana"
}

variable "grafana_admin_password" {
  type        = string
  description = "Custom password for Grafana"
  sensitive   = true
}