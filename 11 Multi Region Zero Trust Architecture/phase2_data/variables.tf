variable "region1" {
  type    = string
  default = "southeastasia"
}

variable "region2" {
  type    = string
  default = "eastasia"
}

variable "admin_username" {
  type    = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}