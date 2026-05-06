# Route Table for SEA Spoke
resource "azurerm_route_table" "rt_spoke_sea" {
  name                = "rt-spoke-sea"
  location            = azurerm_resource_group.spoke_sea.location
  resource_group_name = azurerm_resource_group.spoke_sea.name
}

resource "azurerm_route" "sea_to_fw" {
  name                   = "dg-to-fw-sea"
  resource_group_name    = azurerm_resource_group.spoke_sea.name
  route_table_name       = azurerm_route_table.rt_spoke_sea.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw_sea.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "sea_workload_assoc" {
  subnet_id      = azurerm_subnet.spoke_sea_workload.id
  route_table_id = azurerm_route_table.rt_spoke_sea.id
}

# Route Table for EA Spoke
resource "azurerm_route_table" "rt_spoke_ea" {
  name                = "rt-spoke-ea"
  location            = azurerm_resource_group.spoke_ea.location
  resource_group_name = azurerm_resource_group.spoke_ea.name
}

resource "azurerm_route" "ea_to_fw" {
  name                   = "dg-to-fw-ea"
  resource_group_name    = azurerm_resource_group.spoke_ea.name
  route_table_name       = azurerm_route_table.rt_spoke_ea.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw_ea.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "ea_workload_assoc" {
  subnet_id      = azurerm_subnet.spoke_ea_workload.id
  route_table_id = azurerm_route_table.rt_spoke_ea.id
}