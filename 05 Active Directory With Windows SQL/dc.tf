resource "azurerm_public_ip" "dc_pip" {
  name                = "dc-pip"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "dc_nsg" {
  name                = "dc-nsg"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # security_rule { 
  #   name                       = "Allow-Me"
  #   priority                   = 110
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = "xxx.xxx.xxx.xxx/32" # my public IP address
  #   destination_address_prefix = "*"
  # }
}

resource "azurerm_network_interface" "dc_nic" {
  name                = "dc-nic"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ad_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
    public_ip_address_id          = azurerm_public_ip.dc_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "dc_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.dc_nic.id
  network_security_group_id = azurerm_network_security_group.dc_nsg.id
}

resource "azurerm_windows_virtual_machine" "dc_vm" {
  name                = "dc-01"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = var.dc_vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.dc_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.dc_image["publisher"]
    offer     = var.dc_image["offer"]
    sku       = var.dc_image["sku"]
    version   = var.dc_image["version"]
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/setup-dc.ps1.tftpl", {
    domain_name              = var.domain_name
    admin_username           = var.admin_username
    admin_password           = var.admin_password
    service_account_password = var.service_account_password
  }))

  additional_unattend_content {
    setting = "FirstLogonCommands"
    content = "<FirstLogonCommands><SynchronousCommand><CommandLine>powershell.exe -ExecutionPolicy Unrestricted -Command \"Copy-Item C:\\AzureData\\CustomData.bin C:\\setup-dc.ps1; C:\\setup-dc.ps1\"</CommandLine><Description>Run DC Setup</Description><Order>1</Order></SynchronousCommand></FirstLogonCommands>"
  }

  additional_unattend_content {
    setting = "AutoLogon"
    content = "<AutoLogon><Password><Value>${var.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
  }
}
