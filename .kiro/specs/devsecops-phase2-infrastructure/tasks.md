# Implementation Plan: DevSecOps Phase 2 — Infrastructure and Security Baseline

## Overview

This plan implements the Phase 2 infrastructure provisioning following the module dependency order: Network → ACR + Security → Identity → AKS → Compute, with a GitHub Actions CI/CD pipeline and Checkov security gate. Each task builds incrementally on previous tasks, ensuring no orphaned code. All implementation uses Terraform (HCL), Ansible (YAML), and GitHub Actions workflow (YAML).

**Execution Path:** All code is created in `C:\Users\mfauz\Documents\Terraform\Azure\learning\13 Enterprise DevSecOps Pipeline\phase 2\`. This directory represents the content that would be pushed to the Platform Repository (`devsecops-platform-infrastructure`) created in Phase 1. The Phase 1 scaffold (modules/network, modules/aks, modules/security) is replaced with the full implementations below.

**Relationship to Phase 1 Platform Repository:** Phase 1 created the GitHub repo with placeholder module directories. Phase 2 implements the actual Terraform code. Once Phase 2 is complete and verified locally, the code can be pushed to the Platform Repository to trigger the CI/CD pipeline.

## Tasks

- [x] 1. Set up project structure, providers, and root module scaffolding
  - [x] 1.1 Create the `phase 2/` directory structure with all module directories, ansible directories, and configuration files
    - Create directories: `phase 2/modules/network/`, `phase 2/modules/aks/`, `phase 2/modules/acr/`, `phase 2/modules/security/`, `phase 2/modules/identity/`, `phase 2/modules/compute/`
    - Create directories: `phase 2/ansible/inventory/`, `phase 2/ansible/playbooks/`, `phase 2/ansible/roles/cis-hardening/tasks/`, `phase 2/ansible/roles/admin-tools/tasks/`
    - Create directories: `phase 2/environments/`, `phase 2/.github/workflows/`
    - Note: Phase 1 created placeholder modules (network, aks, security) in the Platform Repository. Phase 2 replaces those placeholders with full implementations and adds new modules (acr, identity, compute).
    - _Requirements: 8.1, 8.6_

  - [x] 1.2 Create `phase 2/providers.tf` with azurerm provider configuration and backend block
    - Configure `azurerm` provider with `~> 3.0` version constraint and `features {}` block
    - Configure `azurerm` backend with storage account `tfstatedevsecops`, resource group `rg-terraform-state`, container `tfstate`, and partial key configuration
    - _Requirements: 11.1, 11.2_

  - [x] 1.3 Create `phase 2/variables.tf` with all root module variable declarations
    - Declare all variables from the design's `.tfvars` schema: `environment`, `location`, `project_name`, `vnet_address_space`, subnet CIDRs, AKS settings, ACR SKU, VM settings, `allowed_rdp_source_ips`, `aks_api_authorized_ips`, `key_vault_admin_object_ids`, `tags`
    - Declare `vm_admin_password` with `sensitive = true`, no default value, and validation rule requiring 12+ characters with uppercase, lowercase, digit, and special character
    - _Requirements: 8.4, 12.1, 12.3_

  - [x] 1.4 Create `phase 2/environments/dev.tfvars` with development environment values
    - Set all non-sensitive variable values for the dev environment per the design document's data model table
    - Ensure `vm_admin_password` is NOT included in this file
    - _Requirements: 8.4, 12.5_

  - [x] 1.5 Create `phase 2/outputs.tf` with root module output declarations
    - Declare outputs for AKS cluster name, ACR login server URL, Key Vault name, VNet ID, and other values consumed by Phase 3/4
    - Mark `kube_config` and any sensitive-derived outputs with `sensitive = true`
    - _Requirements: 12.4_

- [x] 2. Implement Network Module
  - [x] 2.1 Create `phase 2/modules/network/variables.tf` with module input declarations
    - Declare inputs: resource group name, location, environment name, project name, VNet address space (list(string)), subnet CIDR blocks (AKS, app, management)
    - Add validation rule on subnet CIDRs to ensure they are valid CIDR notation
    - _Requirements: 1.6, 1.7_

  - [x] 2.2 Create `phase 2/modules/network/main.tf` with VNet, subnets, NSGs, and associations
    - Create `azurerm_virtual_network` with configurable address space
    - Create three `azurerm_subnet` resources (snet-aks, snet-app, snet-mgmt) with configurable CIDRs
    - Create three `azurerm_network_security_group` resources with deny-all inbound rule at priority 4096
    - Create three `azurerm_subnet_network_security_group_association` resources (NOT inline `network_security_group_id`)
    - Apply naming convention: `vnet-{project}-{env}`, `snet-{purpose}-{project}-{env}`, `nsg-{purpose}-{project}-{env}`
    - Apply mandatory tags (`project`, `environment`) to all resources
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 10.1, 10.2_

  - [x] 2.3 Create `phase 2/modules/network/outputs.tf` with module outputs
    - Output VNet ID, VNet name, subnet IDs (AKS, app, management), NSG IDs
    - _Requirements: 1.5_

  - [x] 2.4 Write Checkov property test configuration for Network Module
    - **Property 1: Network Isolation** — Verify all subnets have associated NSGs with deny-all inbound rules
    - **Property 10: Resource Metadata Compliance** — Verify naming convention and mandatory tags
    - **Validates: Requirements 1.3, 6.3, 10.1, 10.2**

- [x] 3. Implement ACR Module
  - [x] 3.1 Create `phase 2/modules/acr/variables.tf` with module input declarations
    - Declare inputs: resource group name, location, environment name, project name, ACR SKU, app subnet ID, VNet ID
    - _Requirements: 3.1_

  - [x] 3.2 Create `phase 2/modules/acr/main.tf` with ACR, private endpoint, and private DNS zone
    - Create `azurerm_container_registry` with Premium SKU, admin user disabled, public network access disabled
    - Create `azurerm_private_endpoint` targeting "registry" subresource in the app subnet
    - Create `azurerm_private_dns_zone` for `privatelink.azurecr.io`
    - Create `azurerm_private_dns_zone_virtual_network_link` to link DNS zone to VNet
    - Create `azurerm_private_dns_a_record` mapping ACR hostname to private endpoint IP
    - Apply naming convention: `acr{project}{env}` (alphanumeric only)
    - Apply mandatory tags to all resources
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 10.2, 10.3_

  - [x] 3.3 Create `phase 2/modules/acr/outputs.tf` with module outputs
    - Output ACR ID, ACR name, ACR login server URL, private endpoint ID
    - _Requirements: 3.5_

  - [x] 3.4 Write Checkov property test configuration for ACR Module
    - **Property 2: Security Configuration Compliance** — Verify ACR has public network access disabled and admin user disabled
    - **Validates: Requirements 3.2**

- [x] 4. Implement Security Module (Key Vault)
  - [x] 4.1 Create `phase 2/modules/security/variables.tf` with module input declarations
    - Declare inputs: resource group name, location, environment name, project name, tenant ID, managed identity principal ID, admin object IDs, subnet IDs for network rules
    - Mark sensitive variables with `sensitive = true`
    - _Requirements: 4.6, 4.8_

  - [x] 4.2 Create `phase 2/modules/security/main.tf` with Key Vault and role assignments
    - Create `azurerm_key_vault` with RBAC authorization, soft delete (90 days), purge protection enabled
    - Disable public network access and configure network rules allowing access from VNet subnets (snet-aks, snet-mgmt)
    - Assign "Key Vault Secrets User" role to AKS Managed Identity (scoped to Key Vault)
    - Assign "Key Vault Secrets Officer" role to admin identities (scoped to Key Vault)
    - Apply naming convention: `kv-{project}-{env}`
    - Apply mandatory tags to all resources
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.7, 10.1, 10.2_

  - [x] 4.3 Create `phase 2/modules/security/outputs.tf` with module outputs
    - Output Key Vault ID, Key Vault name, Key Vault URI
    - _Requirements: 4.1_

  - [x] 4.4 Write Checkov property test configuration for Security Module
    - **Property 2: Security Configuration Compliance** — Verify Key Vault has soft delete enabled and purge protection enabled
    - **Validates: Requirements 4.2, 4.3**

- [x] 5. Implement Identity Module
  - [x] 5.1 Create `phase 2/modules/identity/variables.tf` with module input declarations
    - Declare inputs: resource group name, location, environment name, project name, ACR ID, Key Vault ID
    - _Requirements: 5.1_

  - [x] 5.2 Create `phase 2/modules/identity/main.tf` with Managed Identity and role assignments
    - Create `azurerm_user_assigned_identity` named `id-aks-{project}-{env}`
    - Create `azurerm_role_assignment` for AcrPull scoped to the specific ACR resource
    - Create `azurerm_role_assignment` for Key Vault Secrets User scoped to the specific Key Vault resource
    - Ensure NO additional roles are assigned beyond AcrPull and Key Vault Secrets User
    - Apply mandatory tags to the managed identity resource
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.6, 10.1, 10.2_

  - [x] 5.3 Create `phase 2/modules/identity/outputs.tf` with module outputs
    - Output managed identity ID, principal ID, and client ID
    - _Requirements: 5.5_

  - [x] 5.4 Write Checkov property test configuration for Identity Module
    - **Property 3: Least Privilege Scoping** — Verify all role assignments are scoped to specific resources, not resource group or subscription
    - **Validates: Requirements 5.2, 5.3, 5.4**

- [-] 6. Checkpoint - Validate foundational modules
  - Ensure all modules (network, acr, security, identity) pass `terraform validate` independently
  - Run `terraform fmt -check` on all module directories
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement AKS Module
  - [x] 7.1 Create `phase 2/modules/aks/variables.tf` with module input declarations
    - Declare inputs: resource group name, location, environment name, project name, AKS subnet ID, managed identity ID, Kubernetes version, node count, node VM size, DNS prefix, authorized IP ranges, Log Analytics workspace ID
    - _Requirements: 2.1, 2.8_

  - [x] 7.2 Create `phase 2/modules/aks/main.tf` with AKS cluster configuration
    - Create `azurerm_kubernetes_cluster` with Azure CNI network plugin
    - Configure single default node pool in AKS subnet with configurable node count and VM size
    - Set identity type to "UserAssigned" referencing the managed identity ID input
    - Enable Kubernetes RBAC
    - Configure `api_server_authorized_ip_ranges` from input variable
    - Disable local accounts (`local_account_disabled = true`)
    - Enable `oms_agent` addon with Log Analytics workspace ID
    - Apply naming convention: `aks-{project}-{env}`
    - Apply mandatory tags to all resources
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 10.1, 10.2_

  - [x] 7.3 Create `phase 2/modules/aks/outputs.tf` with module outputs
    - Output cluster ID, cluster name, kubeconfig (marked `sensitive`), cluster FQDN, node resource group name
    - _Requirements: 2.7_

  - [x] 7.4 Write Checkov property test configuration for AKS Module
    - **Property 2: Security Configuration Compliance** — Verify AKS has RBAC enabled, local accounts disabled, and oms_agent logging enabled
    - **Validates: Requirements 2.3, 2.5, 2.6**

- [x] 8. Implement Compute Module (Jumpbox VM)
  - [x] 8.1 Create `phase 2/modules/compute/variables.tf` with module input declarations
    - Declare inputs: resource group name, location, environment name, project name, management subnet ID, VM size, admin username, admin password (sensitive), VM image reference, allowed RDP source IPs
    - Add validation rule requiring at least one IP in `allowed_rdp_source_ips`
    - _Requirements: 6.1, 6.9_

  - [x] 8.2 Create `phase 2/modules/compute/main.tf` with VM, NIC, public IP, and NSG rules
    - Create `azurerm_public_ip` (Standard SKU) named `pip-jumpbox-{env}`
    - Create `azurerm_network_interface` named `nic-jumpbox-{env}` with private IP in management subnet and public IP association
    - Create `azurerm_network_security_rule` allowing inbound RDP (3389) and WinRM HTTPS (5986) only from `allowed_rdp_source_ips`
    - Create `azurerm_windows_virtual_machine` (Windows Server 2022) named `vm-jumpbox-{env}`
    - Create `azurerm_virtual_machine_extension` (Custom Script Extension) to configure WinRM HTTPS listener with self-signed certificate
    - Add `local-exec` provisioner to execute Ansible playbook after VM creation
    - Apply mandatory tags to all resources
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 10.1, 10.2_

  - [x] 8.3 Create `phase 2/modules/compute/outputs.tf` with module outputs
    - Output VM ID, VM name, VM private IP, VM public IP
    - _Requirements: 6.1_

  - [x] 8.4 Write unit tests for Compute Module variable validation
    - Test that empty `allowed_rdp_source_ips` fails validation
    - Test that valid IP list passes validation
    - _Requirements: 6.9_

- [x] 9. Implement Ansible playbook and roles
  - [x] 9.1 Create `phase 2/ansible/ansible.cfg` with WinRM connection settings
    - Configure connection plugin for WinRM, NTLM transport over HTTPS, port 5986
    - Disable certificate validation (self-signed cert in learning environment)
    - _Requirements: 6.5_

  - [x] 9.2 Create `phase 2/ansible/inventory/hosts.yml.tpl` inventory template
    - Create Jinja2/Terraform template that populates jumpbox IP, admin username, and connection settings
    - Template will be rendered by Terraform `templatefile()` function before Ansible execution
    - _Requirements: 6.5_

  - [x] 9.3 Create `phase 2/ansible/playbooks/jumpbox-config.yml` main playbook
    - Define playbook targeting the jumpbox host group
    - Include roles: `admin-tools` and `cis-hardening`
    - _Requirements: 6.5, 6.6, 6.7_

  - [x] 9.4 Create `phase 2/ansible/roles/admin-tools/tasks/main.yml` role
    - Install kubectl using official Windows installer
    - Install Azure CLI using MSI installer
    - Install helm using official Windows installer
    - Verify each tool is executable by running version commands (`kubectl version --client`, `az version`, `helm version`)
    - _Requirements: 6.6_

  - [x] 9.5 Create `phase 2/ansible/roles/cis-hardening/tasks/main.yml` role
    - Apply CIS Microsoft Windows Server 2022 Benchmark Level 1 hardening tasks
    - Configure audit policies, disable unnecessary services, set registry keys for security settings
    - _Requirements: 6.7_

- [-] 10. Checkpoint - Validate all modules and Ansible
  - Ensure all six modules pass `terraform validate` independently
  - Run `terraform fmt -check` on all `.tf` files
  - Verify Ansible playbook syntax with `ansible-playbook --syntax-check`
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Wire root module — compose all child modules in main.tf
  - [x] 11.1 Create `phase 2/main.tf` composing all child modules with proper dependency ordering
    - Create `azurerm_resource_group` named `rg-{project}-{env}`
    - Instantiate `module.network` passing resource group, location, environment, VNet/subnet CIDRs
    - Instantiate `module.acr` passing resource group, location, environment, app subnet ID from network outputs, VNet ID from network outputs
    - Instantiate `module.security` passing resource group, location, environment, tenant ID, managed identity principal ID from identity outputs, admin object IDs, subnet IDs from network outputs
    - Instantiate `module.identity` passing resource group, location, environment, ACR ID from acr outputs, Key Vault ID from security outputs
    - Instantiate `module.aks` passing resource group, location, environment, AKS subnet ID from network outputs, managed identity ID from identity outputs, Kubernetes version, node settings, authorized IPs
    - Instantiate `module.compute` passing resource group, location, environment, management subnet ID from network outputs, VM settings, allowed RDP IPs
    - Ensure dependency ordering is expressed through implicit output-to-input references (no explicit `depends_on` between modules)
    - Apply mandatory tags to the resource group
    - _Requirements: 8.1, 8.2, 9.1, 10.1, 10.2, 10.4_

  - [x] 11.2 Write property test — validate module independence with terraform validate
    - **Property 7: Module Independence** — Run `terraform validate` on each module directory independently
    - **Validates: Requirements 8.3**

  - [x] 11.3 Write property test — validate zero hardcoded values
    - **Property 8: Zero Hardcoded Values** — Scan all module `.tf` files for hardcoded environment names, CIDRs, or region names
    - **Validates: Requirements 8.4**

  - [x] 11.4 Write property test — validate formatting compliance
    - **Property 9: Formatting Compliance** — Run `terraform fmt -check` on root and all child module directories
    - **Validates: Requirements 8.5**

- [x] 12. Implement Checkov configuration and security scanning
  - [x] 12.1 Create `phase 2/.checkov.yaml` with skip list and justifications
    - Configure framework as `terraform`
    - Define skip checks with documented justifications (e.g., CKV_AZURE_1 skipped because Windows requires password auth)
    - Configure soft-fail for medium/low severity, hard-fail for high/critical
    - _Requirements: 7.2_

  - [x] 12.2 Write Checkov property test — run full scan against all modules
    - **Property 2: Security Configuration Compliance** — Run Checkov against all `.tf` files and verify no high/critical findings
    - **Property 5: Checkov Gate** — Verify Checkov blocks on high/critical severity
    - **Validates: Requirements 7.2, 7.3**

  - [x] 12.3 Write property test — validate sensitive value protection
    - **Property 4: Sensitive Value Protection** — Verify all sensitive outputs have `sensitive = true` flag and no secrets appear in committed files
    - **Validates: Requirements 12.2, 12.3**

  - [x] 12.4 Write property test — validate resource metadata compliance
    - **Property 10: Resource Metadata Compliance** — Verify all resources follow naming convention and have mandatory tags
    - **Validates: Requirements 10.1, 10.2**

- [x] 13. Implement GitHub Actions CI/CD pipeline
  - [x] 13.1 Create `phase 2/.github/workflows/terraform-phase2.yml` workflow file
    - Configure triggers: push to `main` (paths: `phase 2/**`), pull_request (paths: `phase 2/**`), workflow_dispatch with environment input
    - Define job: `security-scan` — checkout code, install Checkov, run Checkov against `phase 2/` with `.checkov.yaml` config, fail on high/critical
    - Define job: `terraform-plan` — depends on `security-scan`, checkout, configure Azure credentials from GitHub Secrets (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`), run `terraform init` with backend key `{env}.terraform.tfstate`, run `terraform plan` with `-var-file="environments/{env}.tfvars"`
    - Define job: `terraform-apply` — depends on `terraform-plan`, runs only on `main` branch, adds runner IP to NSG for WinRM access, runs `terraform apply -auto-approve`, removes temporary NSG rule on completion/failure
    - Inject `TF_VAR_vm_admin_password` from GitHub Secrets as masked environment variable
    - Post Checkov results and plan output as PR comment on pull requests
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 9.3, 9.4, 12.6_

  - [x] 13.2 Write property test — validate pipeline blocks on Checkov failure
    - **Property 5: Checkov Gate** — Verify workflow structure ensures `terraform-apply` job depends on `security-scan` passing
    - **Validates: Requirements 7.3**

- [x] 14. Implement idempotency and sensitive value safeguards
  - [x] 14.1 Update `.gitignore` to exclude sensitive files and Terraform artifacts
    - Add patterns for `*.tfvars` (except `terraform.tfvars.example`), `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `*.tfplan`
    - Ensure `vm_admin_password` cannot be committed via any file
    - _Requirements: 12.5_

  - [x] 14.2 Create `phase 2/terraform.tfvars.example` as a documented variable template
    - Include all variable names with placeholder values and comments explaining each
    - Mark sensitive variables with `# Set via TF_VAR_* environment variable` comment
    - _Requirements: 8.4, 12.5_

  - [x] 14.3 Write property test — validate idempotent apply
    - **Property 6: Idempotent Apply** — Verify that running `terraform plan` after a successful apply shows 0 changes
    - **Validates: Requirements 9.2**

- [x] 15. Phase 2 documentation (per steering rules)
  - [x] 15.1 Create `phase 2/README.md` with all required sections per steering standards
    - **Project overview and architecture**: Describe Phase 2's purpose (infrastructure and security baseline), what it provisions, and how it fits in the 4-phase pipeline
    - **Tools & Skills table**: List all tools used in Phase 2 with columns: Tool Name, DevSecOps Function, Role Description. Tools: Terraform, Checkov, Ansible, Azure VNet, AKS, ACR, Key Vault, NSG, Managed Identity, GitHub Actions
    - **Time estimation**: Estimated `terraform apply` time (~15-20 min) and `terraform destroy` time (~10 min)
    - **Cost estimation**: Estimated daily and monthly Azure costs broken down by resource (AKS nodes, VM jumpbox, ACR Premium, Key Vault, Public IP, storage)
    - **Step-by-step instructions**: Prerequisites (Azure CLI, Terraform, Ansible, pywinrm), setup steps (clone, configure backend, set env vars), and execution commands to run Phase 2 independently
    - **Educational context**: For each tool, explain what it does, why it's needed in DevSecOps, and how it connects to Phase 3 and Phase 4
    - **Verification commands**: `az` CLI commands to confirm all resources are deployed correctly
    - **Troubleshooting**: Common errors and their resolutions (SKU unavailable, WinRM timeout, Key Vault soft-delete conflict, ACR DNS resolution)

  - [x] 15.2 Update project root README (`13 Enterprise DevSecOps Pipeline/README.md`) with Phase 2 information
    - Update the "Time Estimation" section with Phase 2 apply/destroy times
    - Update the "Cost Estimation" section with Phase 2 Azure resource costs
    - Ensure the step-by-step guide includes Phase 2 execution instructions in the correct order
    - Verify the pipeline flow diagram includes Phase 2 tools (Terraform, Checkov, Ansible)

- [-] 16. Final checkpoint - Full validation
  - Run `terraform fmt -check` on all `.tf` files (root and modules)
  - Run `terraform validate` on root module
  - Run Checkov scan against all `phase 2/` Terraform files
  - Verify Ansible playbook syntax
  - Verify `phase 2/README.md` contains all required sections per steering rules
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 17. Deploy and verify — terraform apply with error resolution
  - [-] 17.1 Verify VM SKU availability before first apply
    - Run `az vm list-skus --location southeastasia --size Standard_B2s_v2 --output table` to confirm SKU is available
    - If unavailable, update `vm_size` in `environments/dev.tfvars` to next cheapest available SKU
    - _Requirements: 9.1_

  - [ ] 17.2 Run `terraform apply` and resolve any errors
    - Execute `terraform init -backend-config="key=dev.terraform.tfstate"` in the `phase 2/` directory
    - Execute `terraform apply -var-file="environments/dev.tfvars"` (with `TF_VAR_vm_admin_password` set)
    - If apply fails, diagnose the root cause, fix the Terraform code permanently, and re-run apply
    - Repeat until apply completes with exit code 0 and zero errors
    - _Requirements: 9.1, 9.2_

  - [ ] 17.3 Post-deploy verification — confirm all resources are correctly provisioned
    - Run `az group show --name rg-devsecops-dev` to confirm resource group exists
    - Run `az network vnet show --resource-group rg-devsecops-dev --name vnet-devsecops-dev` to confirm VNet and subnets
    - Run `az aks show --resource-group rg-devsecops-dev --name aks-devsecops-dev` to confirm AKS is Running with correct identity and authorized IPs
    - Run `az acr show --name acrdevsecopsdev --query publicNetworkAccess` to confirm ACR is private
    - Run `az keyvault show --name kv-devsecops-dev` to confirm Key Vault with soft-delete and purge protection
    - Run `az vm show --resource-group rg-devsecops-dev --name vm-jumpbox-dev --show-details` to confirm jumpbox is running
    - Verify Ansible completed: confirm kubectl, az, and helm are installed on the jumpbox
    - _Requirements: 9.1, 10.1, 10.2_

  - [ ] 17.4 Idempotency check — confirm second apply shows zero changes
    - Run `terraform plan -var-file="environments/dev.tfvars"` and confirm output shows "No changes. Your infrastructure matches the configuration."
    - If changes are detected, investigate and fix the non-idempotent resource, then re-apply
    - _Requirements: 9.2_

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical boundaries
- Property tests use Checkov as the property-based testing tool for IaC (static analysis assertions)
- Module dependency ordering is enforced through implicit Terraform references, not explicit `depends_on`
- The Ansible `local-exec` provisioner requires Ansible + pywinrm installed on the machine running Terraform
- All sensitive values flow through environment variables or GitHub Secrets — never in `.tfvars` or source files

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["1.4", "1.5", "2.1", "3.1", "4.1", "5.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "3.2", "3.3", "4.2", "4.3", "5.2", "5.3"] },
    { "id": 3, "tasks": ["2.4", "3.4", "4.4", "5.4", "7.1", "8.1"] },
    { "id": 4, "tasks": ["7.2", "7.3", "7.4", "8.2", "8.3", "8.4"] },
    { "id": 5, "tasks": ["9.1", "9.2", "9.3", "9.4", "9.5"] },
    { "id": 6, "tasks": ["11.1"] },
    { "id": 7, "tasks": ["11.2", "11.3", "11.4", "12.1", "14.1", "14.2"] },
    { "id": 8, "tasks": ["12.2", "12.3", "12.4", "13.1", "14.3"] },
    { "id": 9, "tasks": ["13.2", "15.1", "15.2"] },
    { "id": 10, "tasks": ["17.1"] },
    { "id": 11, "tasks": ["17.2"] },
    { "id": 12, "tasks": ["17.3", "17.4"] }
  ]
}
```
