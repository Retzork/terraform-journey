# SQL Server Primary (SEA)
resource "azurerm_mssql_server" "sql_sea" {
  name                         = "sql-primary-sea-${random_string.suffix.result}"
  resource_group_name          = data.azurerm_resource_group.hub_sea.name
  location                     = var.region1
  version                      = "12.0"
  administrator_login          = var.admin_username
  administrator_login_password = var.admin_password
  public_network_access_enabled = false
}

# SQL Server Secondary (EA)
resource "azurerm_mssql_server" "sql_ea" {
  name                         = "sql-secondary-ea-${random_string.suffix.result}"
  resource_group_name          = data.azurerm_resource_group.hub_ea.name
  location                     = var.region2
  version                      = "12.0"
  administrator_login          = var.admin_username
  administrator_login_password = var.admin_password
  public_network_access_enabled = false
}

# Databases
resource "azurerm_mssql_database" "db_sea" {
  name      = "db-prod-sea"
  server_id = azurerm_mssql_server.sql_sea.id
  sku_name  = "Basic"
}

resource "azurerm_mssql_database" "db_ea" {
  name      = "db-prod-ea"
  server_id = azurerm_mssql_server.sql_ea.id
  sku_name  = "Basic"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}