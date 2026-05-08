# --- ROUTE TABLES ---

resource "azurerm_route_table" "rt_hub_sea" {
  name                = "rt-hub-sea"
  location            = azurerm_resource_group.hub_sea.location
  resource_group_name = azurerm_resource_group.hub_sea.name
}

resource "azurerm_route_table" "rt_hub_ea" {
  name                = "rt-hub-ea"
  location            = azurerm_resource_group.hub_ea.location
  resource_group_name = azurerm_resource_group.hub_ea.name
}

resource "azurerm_route_table" "rt_spoke_sea" {
  name                = "rt-spoke-sea"
  location            = azurerm_resource_group.spoke_sea.location
  resource_group_name = azurerm_resource_group.spoke_sea.name
}

resource "azurerm_route_table" "rt_spoke_ea" {
  name                = "rt-spoke-ea"
  location            = azurerm_resource_group.spoke_ea.location
  resource_group_name = azurerm_resource_group.spoke_ea.name
}

# --- ROUTES: SOUTHEAST ASIA (SEA) ---

# Hub SEA (Jumpbox) -> EA Spoke via SEA Firewall
resource "azurerm_route" "sea_hub_to_ea_spoke" {
  name                   = "to-ea-spoke"
  resource_group_name    = azurerm_resource_group.hub_sea.name
  route_table_name       = azurerm_route_table.rt_hub_sea.name
  address_prefix         = "10.3.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw_sea.ip_configuration[0].private_ip_address
}

# Spoke SEA -> Internet via SEA Firewall
resource "azurerm_route" "sea_spoke_dg" {
  name                   = "dg-to-fw-sea"
  resource_group_name    = azurerm_resource_group.spoke_sea.name
  route_table_name       = azurerm_route_table.rt_spoke_sea.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw_sea.ip_configuration[0].private_ip_address
}

# --- ROUTES: EAST ASIA (EA) ---

# Spoke EA -> Internet via EA Firewall
resource "azurerm_route" "ea_spoke_dg" {
  name                   = "dg-to-fw-ea"
  resource_group_name    = azurerm_resource_group.spoke_ea.name
  route_table_name       = azurerm_route_table.rt_spoke_ea.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw_ea.ip_configuration[0].private_ip_address
}

# Spoke EA -> SEA Hub via EA Firewall (Mandatory for Symmetric Return)
resource "azurerm_route" "ea_spoke_to_sea_hub" {
  name                   = "return-to-sea-hub"
  resource_group_name    = azurerm_resource_group.spoke_ea.name
  route_table_name       = azurerm_route_table.rt_spoke_ea.name
  address_prefix         = "10.0.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw_ea.ip_configuration[0].private_ip_address
}

# --- ASSOCIATIONS ---

resource "azurerm_subnet_route_table_association" "sea_hub_assoc" {
  subnet_id      = azurerm_subnet.hub_sea_mgmt.id
  route_table_id = azurerm_route_table.rt_hub_sea.id
}

resource "azurerm_subnet_route_table_association" "sea_workload_assoc" {
  subnet_id      = azurerm_subnet.spoke_sea_workload.id
  route_table_id = azurerm_route_table.rt_spoke_sea.id
}

resource "azurerm_subnet_route_table_association" "ea_workload_assoc" {
  subnet_id      = azurerm_subnet.spoke_ea_workload.id
  route_table_id = azurerm_route_table.rt_spoke_ea.id
}

# --- FIREWALL ROUTE TABLES (Overcoming Non-Transitive Peering) ---

# SEA Firewall Route Table
resource "azurerm_route_table" "rt_fw_sea" {
  name                = "rt-fw-sea"
  location            = azurerm_resource_group.hub_sea.location
  resource_group_name = azurerm_resource_group.hub_sea.name
}

resource "azurerm_route" "fw_sea_to_ea_spoke" {
  name                   = "fw-to-ea-spoke"
  resource_group_name    = azurerm_resource_group.hub_sea.name
  route_table_name       = azurerm_route_table.rt_fw_sea.name
  address_prefix         = "10.3.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw_ea.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "fw_sea_assoc" {
  subnet_id      = azurerm_subnet.hub_sea_fw.id
  route_table_id = azurerm_route_table.rt_fw_sea.id
}

# EA Firewall Route Table
resource "azurerm_route_table" "rt_fw_ea" {
  name                = "rt-fw-ea"
  location            = azurerm_resource_group.hub_ea.location
  resource_group_name = azurerm_resource_group.hub_ea.name
}

resource "azurerm_route" "fw_ea_to_sea_hub" {
  name                   = "fw-to-sea-hub"
  resource_group_name    = azurerm_resource_group.hub_ea.name
  route_table_name       = azurerm_route_table.rt_fw_ea.name
  address_prefix         = "10.0.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw_sea.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "fw_ea_assoc" {
  subnet_id      = azurerm_subnet.hub_ea_fw.id
  route_table_id = azurerm_route_table.rt_fw_ea.id
}