variable "vm_admin_username" {
  type = string
}

variable "vm_admin_password" {
  type      = string
  sensitive = true
}