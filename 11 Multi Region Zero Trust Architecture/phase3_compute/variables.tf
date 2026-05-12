variable "vm_admin_username" {
  type = string
}

variable "vm_admin_password" {
  type      = string
  sensitive = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the jumpbox (Zero Trust: restrict to your IP)"
  type        = string
  default     = "Internet"
}