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

variable "management_subnet_id" {
  description = "Subnet ID for the jumpbox NIC"
  type        = string
}

variable "vm_size" {
  description = "VM SKU size for the jumpbox"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "admin_username" {
  description = "Admin username for the jumpbox VM"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for the jumpbox VM"
  type        = string
  sensitive   = true
}

variable "vm_image_reference" {
  description = "VM image reference for the jumpbox (publisher, offer, sku, version)"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

variable "allowed_rdp_source_ips" {
  description = "List of IP addresses allowed to RDP and WinRM to the jumpbox"
  type        = list(string)

  validation {
    condition     = length(var.allowed_rdp_source_ips) > 0
    error_message = "At least one source IP is required in allowed_rdp_source_ips."
  }
}

variable "management_nsg_id" {
  description = "NSG ID for adding RDP and WinRM inbound rules"
  type        = string
}
