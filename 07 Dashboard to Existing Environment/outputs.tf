output "grafana_url" {
  description = "The URL to access the Grafana Dashboard"
  value       = "http://${azurerm_public_ip.hub_pip.ip_address}:3000"
}