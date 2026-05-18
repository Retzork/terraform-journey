variable "location" {
  type    = string
  default = "southeastasia"
}

variable "resource_group_name" {
  type    = string
  default = "rg-cicd-bridge"
}

variable "vnet_name" {
  type    = string
  default = "vnet-cicd-bridge"
}

variable "subnet_name" {
  type    = string
  default = "snet-runner"
}

variable "uami_name" {
  type    = string
  default = "uami-github-runner"
}

variable "vm_name" {
  type    = string
  default = "vm-github-runner"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "admin_password" {
  type        = string
  description = "Password for VM authentication. Must meet Azure complexity requirements."
  sensitive   = true
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique name for the storage account (used as remote backend by pipeline)"
  default     = "arthatfstatecicdbrg2026"
}

variable "container_name" {
  type    = string
  default = "tfstate"
}

variable "github_owner" {
  type        = string
  description = "GitHub repository owner or organization name"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "github_pat" {
  type        = string
  description = "GitHub Personal Access Token with 'Administration: Read & Write' permission"
  sensitive   = true
}
