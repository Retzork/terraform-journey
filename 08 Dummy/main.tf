variable "vm_count" {
  description = "Number of VMs to launch"
  type        = number
  default     = 2
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "test_rg" {
  name     = "dummyRG"
  location = "southeastasia"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "dummyVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.test_rg.location
  resource_group_name = azurerm_resource_group.test_rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "dummySubnet"
  resource_group_name  = azurerm_resource_group.test_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "pip-testing"
  location            = azurerm_resource_group.test_rg.location
  resource_group_name = azurerm_resource_group.test_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "nic-testing-${count.index}"
  location            = azurerm_resource_group.test_rg.location
  resource_group_name = azurerm_resource_group.test_rg.name 

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic" 
    public_ip_address_id          = count.index == 0 ? azurerm_public_ip.pip.id : null
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-dummy"
  location            = azurerm_resource_group.test_rg.location
  resource_group_name = azurerm_resource_group.test_rg.name

  # security_rule {
  #   name                       = "RDP-Access-1"
  #   priority                   = 1000
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "3389"
  #   source_address_prefix      = "xxx.xxx.xxx.xxx/32" 
  #   destination_address_prefix = "*"
  # }

  # security_rule {
  #   name                       = "RDP-Access-2"
  #   priority                   = 1010 
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "3389"
  #   source_address_prefix      = "xxx.xxx.xxx.xxx/32" 
  #   destination_address_prefix = "*"
  # }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "vm-dummy-${count.index}"
  resource_group_name = azurerm_resource_group.test_rg.name
  location            = azurerm_resource_group.test_rg.location
  size                = "Standard_B2s_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]

  patch_mode = "AutomaticByPlatform"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition-core-smalldisk"
    version   = "latest"
  }
}

output "public_ip_address" {
  value = azurerm_public_ip.pip.ip_address
}