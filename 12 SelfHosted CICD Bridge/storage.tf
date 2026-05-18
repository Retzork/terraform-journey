# State storage lives in a SEPARATE resource group from the workload.
# This prevents the chicken-and-egg problem: if you destroy the workload RG,
# the state backend survives and Terraform can still function.

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate-cicd-bridge"
  location = var.location
}

resource "azurerm_storage_account" "tfstate" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}
