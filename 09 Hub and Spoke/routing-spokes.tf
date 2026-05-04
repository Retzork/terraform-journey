# Route Table for Spoke A
resource "azurerm_route_table" "rt_spoke_a" {
  name                          = "rt-spoke-a"
  location                      = azurerm_resource_group.lab.location
  resource_group_name           = azurerm_resource_group.lab.name
  bgp_route_propagation_enabled = true

  route {
    name                   = "dg-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub_fw.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "rta_spoke_a" {
  subnet_id      = azurerm_subnet.spoke_a_workload.id
  route_table_id = azurerm_route_table.rt_spoke_a.id
}

# Route Table for Spoke B
resource "azurerm_route_table" "rt_spoke_b" {
  name                          = "rt-spoke-b"
  location                      = azurerm_resource_group.lab.location
  resource_group_name           = azurerm_resource_group.lab.name
  bgp_route_propagation_enabled = true

  route {
    name                   = "dg-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub_fw.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "rta_spoke_b" {
  subnet_id      = azurerm_subnet.spoke_b_workload.id
  route_table_id = azurerm_route_table.rt_spoke_b.id
}