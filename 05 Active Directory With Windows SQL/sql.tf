resource "azurerm_network_interface" "sql_nic" {
  name                = "sql-nic"
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

resource "azurerm_windows_virtual_machine" "sql_vm" {
  name                = "sql-01"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = var.sql_vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.sql_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = var.sql_image["publisher"]
    offer     = var.sql_image["offer"]
    sku       = var.sql_image["sku"]
    version   = var.sql_image["version"]
  }

  depends_on = [
    azurerm_windows_virtual_machine.dc_vm
  ]
}

resource "azurerm_virtual_machine_extension" "sql_domain_join" {
  name                 = "sql-domain-join"
  virtual_machine_id   = azurerm_windows_virtual_machine.sql_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = <<SETTINGS
    {
      "Name": "${var.domain_name}",
      "OUPath": "",
      "User": "${var.domain_name}\\${var.admin_username}",
      "Restart": "true",
      "Options": "3"
    }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "Password": "${var.admin_password}"
    }
  PROTECTED_SETTINGS
}

locals {
  sql_script = templatefile("${path.module}/scripts/setup-sql.ps1.tftpl", {
    domain_name                  = var.domain_name
    service_account_password_b64 = base64encode(var.service_account_password)
  })
}

resource "azurerm_virtual_machine_extension" "sql_config" {
  name                 = "sql-config"
  virtual_machine_id   = azurerm_windows_virtual_machine.sql_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  protected_settings = <<PROTECTED_SETTINGS
    {
      "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -NonInteractive -EncodedCommand ${textencodebase64(local.sql_script, "UTF-16LE")}"
    }
  PROTECTED_SETTINGS
}