resource "azurerm_network_interface" "member_nic" {
  count               = var.domain_member_count
  name                = "member-nic-${count.index + 1}"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  dns_servers         = ["10.0.1.4"]

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ad_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_network_interface.dc_nic
  ]
}

resource "azurerm_windows_virtual_machine" "member_vm" {
  count               = var.domain_member_count
  name                = "member-0${count.index + 1}"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = var.member_vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  depends_on = [
    azurerm_windows_virtual_machine.dc_vm
  ]

  network_interface_ids = [
    azurerm_network_interface.member_nic[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.member_image["publisher"]
    offer     = var.member_image["offer"]
    sku       = var.member_image["sku"]
    version   = var.member_image["version"]
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/setup-member.ps1.tftpl", {
    domain_name    = var.domain_name
    admin_username = var.admin_username
    admin_password = var.admin_password
  }))

  additional_unattend_content {
    setting = "FirstLogonCommands"
    content = "<FirstLogonCommands><SynchronousCommand><CommandLine>powershell.exe -ExecutionPolicy Unrestricted -Command \"Copy-Item C:\\AzureData\\CustomData.bin C:\\setup-member.ps1; C:\\setup-member.ps1\"</CommandLine><Description>Run Domain Join</Description><Order>1</Order></SynchronousCommand></FirstLogonCommands>"
  }

  additional_unattend_content {
    setting = "AutoLogon"
    content = "<AutoLogon><Password><Value>${var.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
  }
}