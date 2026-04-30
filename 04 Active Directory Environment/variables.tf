variable "resource_group_name" {
  type    = string
  default = "ActiveDirectoryEnvironmentRG"
}

variable "location" {
  type    = string
  default = "indonesiacentral"
}

variable "admin_username" {
  type    = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type    = string
}

variable "domain_member_count" { #ganti
  type        = number
  default     = 4
  description = "The number of domain-joined VMs to create automatically"
}

variable "dc_vm_size" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "Virtual Machine size for the Domain Controller"
}

variable "dc_image" {
  type = map(string)
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
  description = "Source image reference for the Domain Controller"
}

variable "member_vm_size" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "Virtual Machine size for the domain members"
}

variable "member_image" {
  type = map(string)
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
  description = "Source image reference for the domain members"
}