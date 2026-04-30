# Hub VM Networking
resource "azurerm_public_ip" "hub_pip" {
  name                = "pip-monitoring-hub"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "hub_nic" {
  name                = "nic-monitoring-hub"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hub_pip.id
  }
}

resource "azurerm_network_security_group" "hub_nsg" {
  name                = "nsg-monitoring-hub"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-Grafana-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = var.admin_ip_address
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "Allow-SSH-Admin"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip_address
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "hub_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.hub_nic.id
  network_security_group_id = azurerm_network_security_group.hub_nsg.id
}

# Hub VM Compute
resource "azurerm_linux_virtual_machine" "hub_vm" {
  name                            = "vm-monitoring-hub"
  resource_group_name             = data.azurerm_resource_group.rg.name
  location                        = data.azurerm_resource_group.rg.location
  size                            = "Standard_B2as_v2"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.hub_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    subscription_id        = var.subscription_id
    resource_group         = data.azurerm_resource_group.rg.name
    dashboard_json         = file("${path.module}/dashboard.json")
    grafana_admin_user     = var.grafana_admin_user
    grafana_admin_password = var.grafana_admin_password
  }))
}

# Prometheus Azure SD Role Assignment
resource "azurerm_role_assignment" "prom_reader" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.hub_vm.identity[0].principal_id
}

locals {
  windows_vm_map = {
    for vm in data.azurerm_resources.windows_vms.resources : 
    vm.name => vm.id 
    if lookup(vm.tags, "os_type", "") != "Linux" # Generic safety check
  }

  raw_dashboard = file("${path.module}/dashboard.json")
  
  sanitized_dashboard = jsonencode(merge(
    jsondecode(local.raw_dashboard), 
    {
      schemaVersion = 39,
      uid           = "windows-monitoring"
    }
  ))
}

resource "azurerm_virtual_machine_extension" "windows_exporter" {
  # ONLY target Windows VMs
  for_each = { 
    for vm in data.azurerm_resources.windows_vms.resources : vm.name => vm.id 
    if vm.name != azurerm_linux_virtual_machine.hub_vm.name 
  }

  name                 = "Deploy-Windows-Exporter"
  virtual_machine_id   = each.value
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    "commandToExecute" = "powershell.exe -ExecutionPolicy Unrestricted -Command \"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $url = 'https://github.com/prometheus-community/windows_exporter/releases/download/v0.31.6/windows_exporter-0.31.6-amd64.msi'; try { Invoke-WebRequest -Uri $url -OutFile windows_exporter.msi -UseBasicParsing -ErrorAction Stop; Start-Process msiexec.exe -ArgumentList '/i windows_exporter.msi /qn ENABLED_COLLECTORS=cpu,memory,os,logical_disk,net,system /l*v exporter_install.log' -Wait; New-NetFirewallRule -DisplayName 'Allow Prometheus' -Direction Inbound -LocalPort 9182 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue } catch { Write-Error $_.Exception.Message; exit 1 }\""
  })
}