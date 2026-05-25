resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name           = "default"
    node_count     = var.node_count
    vm_size        = var.node_vm_size
    vnet_subnet_id = var.aks_subnet_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  role_based_access_control_enabled = true
  local_account_disabled            = true

  api_server_access_profile {
    authorized_ip_ranges = var.api_authorized_ip_ranges
  }

  network_profile {
    network_plugin = "azure"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}
