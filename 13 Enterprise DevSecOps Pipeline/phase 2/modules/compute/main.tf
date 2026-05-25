# -----------------------------------------------------------------------------
# Compute Module - Jumpbox VM with Ansible Provisioning
# -----------------------------------------------------------------------------

# --- Public IP ---
resource "azurerm_public_ip" "jumpbox" {
  name                = "pip-jumpbox-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}

# --- Network Interface ---
resource "azurerm_network_interface" "jumpbox" {
  name                = "nic-jumpbox-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.management_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}

# --- NSG Rules ---
resource "azurerm_network_security_rule" "allow_rdp" {
  name                        = "Allow-RDP-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefixes     = var.allowed_rdp_source_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = split("/", var.management_nsg_id)[8]
}

resource "azurerm_network_security_rule" "allow_winrm" {
  name                        = "Allow-WinRM-HTTPS-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5986"
  source_address_prefixes     = var.allowed_rdp_source_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = split("/", var.management_nsg_id)[8]
}

# --- Windows Virtual Machine ---
resource "azurerm_windows_virtual_machine" "jumpbox" {
  name                = "vm-jumpbox-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.jumpbox.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image_reference.publisher
    offer     = var.vm_image_reference.offer
    sku       = var.vm_image_reference.sku
    version   = var.vm_image_reference.version
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}

# --- WinRM HTTPS Configuration Extension ---
resource "azurerm_virtual_machine_extension" "winrm_https" {
  name                 = "configure-winrm-https"
  virtual_machine_id   = azurerm_windows_virtual_machine.jumpbox.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\\LocalMachine\\My; Enable-PSRemoting -Force; New-Item -Path WSMan:\\LocalHost\\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force; New-NetFirewallRule -DisplayName 'WinRM HTTPS' -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow; Set-Item WSMan:\\localhost\\Service\\Auth\\Basic -Value $true; Restart-Service WinRM\""
  })

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}

# --- Rendered Ansible Inventory ---
resource "local_file" "ansible_inventory" {
  depends_on = [azurerm_virtual_machine_extension.winrm_https]

  content = templatefile("${path.module}/../../ansible/inventory/hosts.yml.tpl", {
    jumpbox_ip     = azurerm_public_ip.jumpbox.ip_address
    admin_username = var.admin_username
    admin_password = var.admin_password
  })

  filename = "${path.module}/../../ansible/inventory/hosts.yml"
}

# --- Ansible Provisioner (local-exec) ---
resource "null_resource" "ansible_provisioner" {
  depends_on = [
    azurerm_virtual_machine_extension.winrm_https,
    local_file.ansible_inventory
  ]

  triggers = {
    vm_id = azurerm_windows_virtual_machine.jumpbox.id
  }

  provisioner "local-exec" {
    command     = "ansible-playbook -i ${path.module}/../../ansible/inventory/hosts.yml ${path.module}/../../ansible/playbooks/jumpbox-config.yml"
    working_dir = "${path.module}/../../ansible"
  }
}
