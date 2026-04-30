output "web_public_ip" {
  description = "The public IP address of the Web Tier"
  value       = azurerm_public_ip.web_pip.ip_address
}