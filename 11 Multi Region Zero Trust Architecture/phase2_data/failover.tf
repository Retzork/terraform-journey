resource "azurerm_mssql_failover_group" "sql_fg" {
  name      = "fg-prod-${random_string.suffix.result}"
  server_id = azurerm_mssql_server.sql_sea.id
  databases = [
    azurerm_mssql_database.db_sea.id
  ]

  partner_server {
    id = azurerm_mssql_server.sql_ea.id
  }

  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = 60
  }
}