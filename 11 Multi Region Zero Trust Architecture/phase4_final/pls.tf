resource "azurerm_private_link_service" "pls_sea" {
  name                = "pls-aks-sea"
  location            = data.azurerm_resource_group.spoke_sea.location
  resource_group_name = data.azurerm_resource_group.spoke_sea.name

  nat_ip_configuration {
    name      = "primary"
    primary   = true
    subnet_id = data.azurerm_subnet.sea_workload.id
  }

  load_balancer_frontend_ip_configuration_ids = [
    data.azurerm_lb.ilb_sea.frontend_ip_configuration[0].id
  ]
}

resource "azurerm_private_link_service" "pls_ea" {
  name                = "pls-aks-ea"
  location            = data.azurerm_resource_group.spoke_ea.location
  resource_group_name = data.azurerm_resource_group.spoke_ea.name

  nat_ip_configuration {
    name      = "primary"
    primary   = true
    subnet_id = data.azurerm_subnet.ea_workload.id
  }

  load_balancer_frontend_ip_configuration_ids = [
    data.azurerm_lb.ilb_ea.frontend_ip_configuration[0].id
  ]
}

# ─── Auto-approve Front Door Private Link connections ───────────────────────
# Front Door creates PE connections from a Microsoft-managed subscription,
# so auto_approval_subscription_ids on the PLS won't work. We approve via CLI
# after the Front Door origin establishes the connection.

resource "null_resource" "approve_pls_sea" {
  depends_on = [azurerm_cdn_frontdoor_origin.origin_sea]

  provisioner "local-exec" {
    interpreter = ["powershell", "-Command"]
    command     = <<-EOT
      Start-Sleep -Seconds 30
      $conns = az network private-link-service show --name ${azurerm_private_link_service.pls_sea.name} --resource-group ${data.azurerm_resource_group.spoke_sea.name} --query "privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending'].name" -o tsv
      foreach ($conn in $conns) {
        if ($conn) {
          az network private-link-service connection update --service-name ${azurerm_private_link_service.pls_sea.name} --resource-group ${data.azurerm_resource_group.spoke_sea.name} --name $conn --connection-status Approved --description "Auto-approved for Front Door"
        }
      }
    EOT
  }

  triggers = {
    pls_id    = azurerm_private_link_service.pls_sea.id
    origin_id = azurerm_cdn_frontdoor_origin.origin_sea.id
  }
}

resource "null_resource" "approve_pls_ea" {
  depends_on = [azurerm_cdn_frontdoor_origin.origin_ea]

  provisioner "local-exec" {
    interpreter = ["powershell", "-Command"]
    command     = <<-EOT
      Start-Sleep -Seconds 30
      $conns = az network private-link-service show --name ${azurerm_private_link_service.pls_ea.name} --resource-group ${data.azurerm_resource_group.spoke_ea.name} --query "privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending'].name" -o tsv
      foreach ($conn in $conns) {
        if ($conn) {
          az network private-link-service connection update --service-name ${azurerm_private_link_service.pls_ea.name} --resource-group ${data.azurerm_resource_group.spoke_ea.name} --name $conn --connection-status Approved --description "Auto-approved for Front Door"
        }
      }
    EOT
  }

  triggers = {
    pls_id    = azurerm_private_link_service.pls_ea.id
    origin_id = azurerm_cdn_frontdoor_origin.origin_ea.id
  }
}