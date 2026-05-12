data "azurerm_subscription" "current" {}

resource "azurerm_policy_definition" "deny_pip_compute" {
  name         = "deny-public-ips-compute"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deny Public IPs on Compute Resources"
  description  = "Enforces Zero-Trust by preventing network interfaces from associating with public IP addresses."
  
  metadata = <<METADATA
    {
      "category": "Network"
    }
  METADATA

  policy_rule = <<POLICY_RULE
  {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Network/networkInterfaces"
        },
        {
          "field": "Microsoft.Network/networkInterfaces/ipConfigurations[*].publicIPAddress.id",
          "exists": "true"
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }
  POLICY_RULE
}

resource "azurerm_subscription_policy_assignment" "deny_pip_assignment" {
  name                 = "assign-deny-public-ips"
  policy_definition_id = azurerm_policy_definition.deny_pip_compute.id
  subscription_id      = data.azurerm_subscription.current.id
  display_name         = "Deny Public IPs on Compute Resources"
}

resource "azurerm_resource_policy_exemption" "jumpbox_pip_exemption" {
  name                 = "exempt-jumpbox-pip"
  resource_id          = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/rg-hub-sea/providers/Microsoft.Network/networkInterfaces/nic-jumpbox-sea"
  policy_assignment_id = azurerm_subscription_policy_assignment.deny_pip_assignment.id
  exemption_category   = "Waiver"
  display_name         = "Jumpbox requires public IP for SSH management access"
  description          = "The jumpbox NIC is the sole authorized exception to the deny-public-IP policy, as it serves as the single entry point for cluster management."
}