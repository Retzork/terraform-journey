data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "hub_sea" {
  name = "rg-hub-sea"
}

data "azurerm_resource_group" "spoke_sea" {
  name = "rg-spoke-sea"
}

data "azurerm_resource_group" "spoke_ea" {
  name = "rg-spoke-ea"
}

data "azurerm_kubernetes_cluster" "aks_sea" {
  name                = "aks-spoke-sea"
  resource_group_name = data.azurerm_resource_group.spoke_sea.name
}

data "azurerm_kubernetes_cluster" "aks_ea" {
  name                = "aks-spoke-ea"
  resource_group_name = data.azurerm_resource_group.spoke_ea.name
}

data "azurerm_subnet" "sea_workload" {
  name                 = "snet-workload-sea"
  virtual_network_name = "vnet-spoke-sea"
  resource_group_name  = data.azurerm_resource_group.spoke_sea.name
}

data "azurerm_subnet" "ea_workload" {
  name                 = "snet-workload-ea"
  virtual_network_name = "vnet-spoke-ea"
  resource_group_name  = data.azurerm_resource_group.spoke_ea.name
}

data "azurerm_lb" "ilb_sea" {
  name                = "kubernetes-internal"
  resource_group_name = data.azurerm_kubernetes_cluster.aks_sea.node_resource_group
  depends_on          = [null_resource.bootstrap_sea]
}

data "azurerm_lb" "ilb_ea" {
  name                = "kubernetes-internal"
  resource_group_name = data.azurerm_kubernetes_cluster.aks_ea.node_resource_group
  depends_on          = [null_resource.bootstrap_ea]
}