variable "resource_group_name" {
  type    = string
  default = "ActiveDirectoryWithSQLRG"
}

variable "location" {
  type    = string
  default = "southeastasia"
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
  default     = 0
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

variable "sql_vm_size" {
  type        = string
  default     = "Standard_D2ads_v5"
  description = "Virtual Machine size for the SQL Server"
}

variable "sql_image" {
  type = map(string)
  default = {
    publisher = "microsoftsqlserver"
    offer     = "sql2019-ws2019"
    sku       = "sqldev-gen2"
    version   = "latest"
  }
  description = "Source image reference for the SQL Server"
}

variable "service_account_password" {
  type        = string
  description = "Password for the Active Directory service accounts"
  sensitive   = true
}