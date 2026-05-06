# Private Endpoint for SEA SQL
resource "azurerm_private_endpoint" "pe_sql_sea" {
  name                = "pe-sql-sea"
  location            = var.region1
  resource_group_name = data.azurerm_resource_group.hub_sea.name
  subnet_id           = data.azurerm_subnet.sea_workload.id

  private_service_connection {
    name                           = "sql-privatelink-sea"
    private_connection_resource_id = azurerm_mssql_server.sql_sea.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-sea"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql_dns.id]
  }
}

# Private Endpoint for EA SQL
resource "azurerm_private_endpoint" "pe_sql_ea" {
  name                = "pe-sql-ea"
  location            = var.region2
  resource_group_name = data.azurerm_resource_group.hub_ea.name
  subnet_id           = data.azurerm_subnet.ea_workload.id

  private_service_connection {
    name                           = "sql-privatelink-ea"
    private_connection_resource_id = azurerm_mssql_server.sql_ea.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-ea"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql_dns.id]
  }
}