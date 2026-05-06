# AKS Cluster - Southeast Asia
resource "azurerm_kubernetes_cluster" "aks_sea" {
  name                    = "aks-spoke-sea"
  location                = data.azurerm_resource_group.spoke_sea.location
  resource_group_name     = data.azurerm_resource_group.spoke_sea.name
  dns_prefix              = "akssea"
  private_cluster_enabled = true
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                        = "default"
    node_count                  = 1
    vm_size                     = "Standard_B2s_v2"
    vnet_subnet_id              = data.azurerm_subnet.sea_workload.id
    temporary_name_for_rotation = "tempnodepool"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }
}

# AKS Cluster - East Asia
resource "azurerm_kubernetes_cluster" "aks_ea" {
  name                    = "aks-spoke-ea"
  location                = data.azurerm_resource_group.spoke_ea.location
  resource_group_name     = data.azurerm_resource_group.spoke_ea.name
  dns_prefix              = "aksea"
  private_cluster_enabled = true
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                        = "default"
    node_count                  = 1
    vm_size                     = "Standard_B2s_v2"
    vnet_subnet_id              = data.azurerm_subnet.ea_workload.id
    temporary_name_for_rotation = "tempnodepool"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }
}