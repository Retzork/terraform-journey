data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "aks-cluster"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "aks-cluster-dns"

  # v4.x Argument: Set to false to allow kube_admin_config to work
  local_account_disabled = false 
  
  # v4.x Required Argument
  role_based_access_control_enabled = true

  default_node_pool {
    name                = "systempool"
    vm_size             = "Standard_B2s_v2"
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 3
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.1.0.0/16"
    dns_service_ip    = "10.1.0.10"
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = [data.azurerm_client_config.current.object_id]
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
}

resource "azurerm_role_assignment" "aks_admin" {
  scope                = azurerm_kubernetes_cluster.aks_cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = data.azurerm_client_config.current.object_id
}