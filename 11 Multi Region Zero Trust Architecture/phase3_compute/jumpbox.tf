# Data source for the new Management Subnet
data "azurerm_subnet" "hub_sea_mgmt" {
  name                 = "snet-mgmt-sea"
  virtual_network_name = "vnet-hub-sea"
  resource_group_name  = "rg-hub-sea"
}

# Public IP for SSH access
resource "azurerm_public_ip" "jumpbox_pip" {
  name                = "pip-jumpbox-sea"
  location            = "southeastasia"
  resource_group_name = "rg-hub-sea"
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface
resource "azurerm_network_interface" "jumpbox_nic" {
  name                = "nic-jumpbox-sea"
  location            = "southeastasia"
  resource_group_name = "rg-hub-sea"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.hub_sea_mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox_pip.id
  }
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                            = "vm-jumpbox-sea"
  resource_group_name             = "rg-hub-sea"
  location                        = "southeastasia"
  size                            = "Standard_B2s_v2"
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.jumpbox_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Network Security Group for Jumpbox
resource "azurerm_network_security_group" "jumpbox_nsg" {
  name                = "nsg-jumpbox-sea"
  location            = "southeastasia"
  resource_group_name = "rg-hub-sea"

  security_rule {
    name                       = "AllowSSHInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # Recommendation: Change to your local Public IP for better security
    destination_address_prefix = "*"
  }
}

# Associate NSG with the Jumpbox NIC
resource "azurerm_network_interface_security_group_association" "jumpbox_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.jumpbox_nic.id
  network_security_group_id = azurerm_network_security_group.jumpbox_nsg.id
}