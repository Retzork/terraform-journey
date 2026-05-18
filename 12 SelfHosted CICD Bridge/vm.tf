resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.vm_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = var.vm_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B2s_v2"
  admin_username                  = var.admin_username
  
  disable_password_authentication = false
  admin_password                  = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

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

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.runner_identity.id]
  }
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y ca-certificates curl gnupg jq zip

    # Install Azure CLI
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker ${var.admin_username}
    
    mkdir -p /home/${var.admin_username}/actions-runner
    cd /home/${var.admin_username}/actions-runner
    curl -o actions-runner-linux-x64-2.316.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.316.1/actions-runner-linux-x64-2.316.1.tar.gz
    tar xzf ./actions-runner-linux-x64-2.316.1.tar.gz
    chown -R ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/actions-runner
    
    # Fetch registration token from GitHub API with error handling
    HTTP_STATUS=$(curl -s -w "%%{http_code}" -o response.json -X POST -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${var.github_pat}" https://api.github.com/repos/${var.github_owner}/${var.github_repo}/actions/runners/registration-token)
    
    if [ "$HTTP_STATUS" -ne 201 ]; then
      echo "Error: Failed to retrieve GitHub registration token. HTTP Status: $HTTP_STATUS"
      cat response.json
      exit 1
    fi
    
    REG_TOKEN=$(jq -r .token response.json)
    
    # Configure runner unattended
    sudo -u ${var.admin_username} ./config.sh --unattended --url https://github.com/${var.github_owner}/${var.github_repo} --token $REG_TOKEN
    
    # Install and start the runner service
    ./svc.sh install ${var.admin_username}
    ./svc.sh start
    EOF
  )

}