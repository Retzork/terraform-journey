resource "azurerm_cdn_frontdoor_profile" "fd_global" {
  name                = "fd-zerotrust-global"
  resource_group_name = data.azurerm_resource_group.hub_sea.name
  sku_name            = "Premium_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "fd_endpoint" {
  name                     = "ep-zerotrust-app"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd_global.id
}

resource "azurerm_cdn_frontdoor_origin_group" "fd_og" {
  name                     = "og-aks-internal"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd_global.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Http"
    interval_in_seconds = 30
  }
}

resource "azurerm_cdn_frontdoor_origin" "origin_sea" {
  name                           = "origin-sea"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.fd_og.id
  enabled                        = true
  host_name                      = "aks-sea.internal"
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = "aks-sea.internal"
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true

  private_link {
    request_message        = "Request from Global Front Door"
    location               = "southeastasia"
    private_link_target_id = azurerm_private_link_service.pls_sea.id
  }
}

resource "azurerm_cdn_frontdoor_origin" "origin_ea" {
  name                           = "origin-ea"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.fd_og.id
  enabled                        = true
  host_name                      = "aks-ea.internal"
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = "aks-ea.internal"
  priority                       = 2
  weight                         = 1000
  certificate_name_check_enabled = true

  private_link {
    request_message        = "Request from Global Front Door"
    location               = "eastasia"
    private_link_target_id = azurerm_private_link_service.pls_ea.id
  }
}

resource "azurerm_cdn_frontdoor_route" "fd_route" {
  name                          = "route-aks"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.fd_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_og.id
  cdn_frontdoor_origin_ids      = [
    azurerm_cdn_frontdoor_origin.origin_sea.id,
    azurerm_cdn_frontdoor_origin.origin_ea.id
  ]
  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/*"]
  forwarding_protocol           = "HttpsOnly"
  link_to_default_domain        = true
  https_redirect_enabled        = true
}