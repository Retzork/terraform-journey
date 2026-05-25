# Compute Module Variable Validation Tests
# Validates: Requirements 6.9
# Tests that allowed_rdp_source_ips variable validation works correctly

# Test: Empty allowed_rdp_source_ips list fails validation
run "empty_rdp_source_ips_fails" {
  command = plan

  module {
    source = "./modules/compute"
  }

  variables {
    resource_group_name    = "rg-test-dev"
    location               = "southeastasia"
    environment            = "dev"
    project_name           = "devsecops"
    management_subnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-mgmt"
    admin_password         = "TestP@ssw0rd123"
    management_nsg_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/nsg-mgmt"
    allowed_rdp_source_ips = []
  }

  expect_failures = [
    var.allowed_rdp_source_ips,
  ]
}

# Test: Valid IP list passes validation
run "valid_rdp_source_ips_passes" {
  command = plan

  module {
    source = "./modules/compute"
  }

  variables {
    resource_group_name    = "rg-test-dev"
    location               = "southeastasia"
    environment            = "dev"
    project_name           = "devsecops"
    management_subnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-mgmt"
    admin_password         = "TestP@ssw0rd123"
    management_nsg_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/nsg-mgmt"
    allowed_rdp_source_ips = ["10.0.0.1/32", "192.168.1.0/24"]
  }
}
