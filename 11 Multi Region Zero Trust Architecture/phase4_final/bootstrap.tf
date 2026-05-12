resource "local_file" "ilb_yaml" {
  filename = "${path.module}/ilb.yaml"
  content  = <<-EOF
  apiVersion: v1
  kind: Service
  metadata:
    name: trigger-ilb
    namespace: default
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
  spec:
    type: LoadBalancer
    ports:
    - port: 80
    selector:
      app: dummy
  EOF
}

resource "null_resource" "bootstrap_sea" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    environment = {
      NODE_RG = data.azurerm_kubernetes_cluster.aks_sea.node_resource_group
    }
    command = <<-EOT
      Write-Host "Pushing LoadBalancer Service to private SEA Cluster..."
      az aks command invoke --resource-group rg-spoke-sea --name aks-spoke-sea --command "kubectl apply -f ilb.yaml" --file ${local_file.ilb_yaml.filename}
      
      Write-Host "Waiting for AKS to provision the Internal Load Balancer in SEA..."
      do {
        Start-Sleep -Seconds 10
        $lb = az network lb list --resource-group $env:NODE_RG --query "[?name=='kubernetes-internal']" | ConvertFrom-Json
      } until ($null -ne $lb -and $lb.Count -gt 0)
    EOT
  }
  depends_on = [local_file.ilb_yaml]
}

resource "null_resource" "bootstrap_ea" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    environment = {
      NODE_RG = data.azurerm_kubernetes_cluster.aks_ea.node_resource_group
    }
    command = <<-EOT
      Write-Host "Pushing LoadBalancer Service to private EA Cluster..."
      az aks command invoke --resource-group rg-spoke-ea --name aks-spoke-ea --command "kubectl apply -f ilb.yaml" --file ${local_file.ilb_yaml.filename}
      
      Write-Host "Waiting for AKS to provision the Internal Load Balancer in EA..."
      do {
        Start-Sleep -Seconds 10
        $lb = az network lb list --resource-group $env:NODE_RG --query "[?name=='kubernetes-internal']" | ConvertFrom-Json
      } until ($null -ne $lb -and $lb.Count -gt 0)
    EOT
  }
  depends_on = [local_file.ilb_yaml]
}