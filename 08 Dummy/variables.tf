variable "admin_username" {
  type        = string
  description = "Admin username for the Linux Hub VM"
}

variable "admin_password" {
  type        = string
  description = "Password for the Linux Hub VM"
  sensitive   = true
}