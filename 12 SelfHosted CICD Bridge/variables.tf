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
  description = "Globally unique name for the storage account"
  default     = "arthatfstatecicdbrg2026" # Must be updated to a globally unique value
}

variable "container_name" {
  type    = string
  default = "tfstate"
}

variable "app_service_plan_name" {
  type    = string
  default = "asp-cicd-bridge"
}

variable "web_app_name" {
  type        = string
  description = "Must be globally unique"
  default     = "app-cicd-bridge-2026-artha"
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
  description = "GitHub Personal Access Token with 'repo' scope"
  sensitive   = true
}