# Requirements Document

## Introduction

This document defines the requirements for DevSecOps Phase 2 — Infrastructure and Security Baseline. Phase 2 provisions the core Azure cloud infrastructure that all subsequent phases depend on: an isolated virtual network with purpose-specific subnets, a private container registry (ACR), a secrets vault (Key Vault), a managed Kubernetes cluster (AKS), an administrative jumpbox configured via Ansible, and a GitHub Actions CI/CD pipeline with Checkov security scanning as a mandatory gate.

These requirements are derived from the approved design document and ensure traceability between the technical architecture and formal specifications.

## Glossary

- **Terraform**: Declarative infrastructure-as-code provisioning tool used to define and deploy all Azure resources
- **Checkov**: Static analysis tool for infrastructure-as-code that detects security misconfigurations before deployment
- **Ansible**: Configuration management tool used for post-deployment jumpbox hardening and tool installation
- **AKS**: Azure Kubernetes Service — managed Kubernetes cluster for container orchestration
- **ACR**: Azure Container Registry — private container image registry
- **Key_Vault**: Azure Key Vault — centralized secrets management service with RBAC access control
- **VNet**: Azure Virtual Network — isolated network boundary containing all Phase 2 resources
- **NSG**: Network Security Group — Azure firewall rules applied at the subnet level
- **Managed_Identity**: Azure User Assigned Managed Identity — credential-free authentication mechanism for Azure-to-Azure communication
- **Jumpbox**: Windows Server VM in the management subnet used as the sole administrative entry point
- **Pipeline**: GitHub Actions CI/CD workflow that orchestrates Checkov scanning and Terraform deployment
- **Private_Endpoint**: Azure networking construct that exposes a PaaS service (ACR) on a private IP within the VNet
- **CIS_Benchmarks**: Center for Internet Security hardening standards applied to the jumpbox via Ansible
- **Root_Module**: The top-level Terraform configuration (`main.tf`) that composes all child modules
- **Network_Module**: Terraform module (`modules/network/`) responsible for VNet, subnets, and NSGs
- **AKS_Module**: Terraform module (`modules/aks/`) responsible for the Kubernetes cluster
- **ACR_Module**: Terraform module (`modules/acr/`) responsible for the container registry and private endpoint
- **Security_Module**: Terraform module (`modules/security/`) responsible for Key Vault
- **Identity_Module**: Terraform module (`modules/identity/`) responsible for Managed Identity and role assignments
- **Compute_Module**: Terraform module (`modules/compute/`) responsible for the jumpbox VM and Ansible provisioning

## Requirements

### Requirement 1: Network Provisioning

**User Story:** As a platform engineer, I want an isolated virtual network with purpose-specific subnets and security groups, so that all Phase 2 resources operate within defined network boundaries with least-privilege traffic rules.

#### Acceptance Criteria

1. WHEN the Network_Module is applied, THE Network_Module SHALL create a VNet with a configurable address space (default 10.0.0.0/16) that accepts any valid CIDR block between /8 and /24
2. WHEN the Network_Module is applied, THE Network_Module SHALL create three subnets within the VNet address space: AKS (snet-aks, default 10.0.1.0/24), application (snet-app, default 10.0.2.0/24), and management (snet-mgmt, default 10.0.3.0/24) with configurable CIDR ranges
3. WHEN the Network_Module is applied, THE Network_Module SHALL create one NSG per subnet with a deny-all inbound rule at priority 4096 (lowest precedence) that blocks all inbound traffic by default
4. WHEN NSGs are created, THE Network_Module SHALL associate NSGs with subnets using separate `azurerm_subnet_network_security_group_association` resources rather than inline `network_security_group_id` attributes
5. WHEN the Network_Module completes, THE Network_Module SHALL output VNet ID, VNet name, all three subnet IDs (AKS, app, management), and all three NSG IDs as named outputs consumable by other modules
6. THE Network_Module SHALL accept the following input variables: resource group name, location, environment name, VNet address space, and individual subnet CIDR blocks (AKS, app, management)
7. IF a subnet CIDR block is provided that does not fall within the VNet address space, THEN THE Network_Module SHALL fail validation before resource creation with an error message indicating the CIDR conflict

### Requirement 2: Kubernetes Cluster Provisioning

**User Story:** As a platform engineer, I want a managed Kubernetes cluster integrated with the VNet and Managed Identity, so that containerized workloads run in a secure, network-isolated environment with credential-free Azure access.

#### Acceptance Criteria

1. WHEN the AKS_Module is applied, THE AKS_Module SHALL create an AKS cluster using the Azure CNI network plugin with a single default node pool deployed into the AKS subnet, where the node count and node VM size are provided as input variables
2. WHEN the AKS cluster is created, THE AKS_Module SHALL assign the User Assigned Managed_Identity by setting the identity type to "UserAssigned" and referencing the managed identity ID received as an input variable
3. WHEN the AKS cluster is created, THE AKS_Module SHALL enable Kubernetes RBAC on the cluster
4. WHEN the AKS cluster is created, THE AKS_Module SHALL configure `api_server_authorized_ip_ranges` using a list of CIDR ranges received as an input variable to restrict API server access to the jumpbox public IP and pipeline runner IPs
5. WHEN the AKS cluster is created, THE AKS_Module SHALL disable local accounts to enforce Managed Identity authentication only
6. WHEN the AKS cluster is created, THE AKS_Module SHALL enable the `oms_agent` addon configured with a Log Analytics workspace ID received as an input variable to satisfy Checkov check CKV_AZURE_4
7. WHEN the AKS_Module completes, THE AKS_Module SHALL output the cluster ID, cluster name, kubeconfig (marked sensitive), cluster FQDN, and node resource group name
8. WHEN the AKS_Module is applied, THE AKS_Module SHALL accept a Kubernetes version as an input variable and use it to set the cluster orchestrator version

### Requirement 3: Private Container Registry

**User Story:** As a platform engineer, I want a private container registry accessible only from within the VNet, so that container images are protected from unauthorized external access following zero-trust principles.

#### Acceptance Criteria

1. WHEN the ACR_Module is applied, THE ACR_Module SHALL create an ACR with Premium SKU and with the admin user disabled
2. WHEN the ACR is created, THE ACR_Module SHALL disable public network access on the ACR by setting `public_network_access_enabled` to false
3. WHEN the ACR is created, THE ACR_Module SHALL create a private endpoint targeting the "registry" subresource in the application subnet (snet-app)
4. WHEN the private endpoint is created, THE ACR_Module SHALL create a private DNS zone (`privatelink.azurecr.io`), link it to the VNet via a virtual network link, and register an A record mapping the ACR login server hostname to the private endpoint IP address
5. WHEN the ACR_Module completes, THE ACR_Module SHALL output the ACR ID, ACR name, ACR login server URL, and private endpoint ID

### Requirement 4: Secrets Management

**User Story:** As a platform engineer, I want a centralized secrets vault with RBAC-based access control, so that sensitive values are never stored in code or configuration files and access is auditable.

#### Acceptance Criteria

1. WHEN the Security_Module is applied, THE Security_Module SHALL create a Key_Vault with RBAC authorization mode (not access policies)
2. WHEN the Key_Vault is created, THE Security_Module SHALL enable soft delete with a 90-day retention period
3. WHEN the Key_Vault is created, THE Security_Module SHALL enable purge protection
4. WHEN the Key_Vault is created, THE Security_Module SHALL assign the "Key Vault Secrets User" role to the AKS Managed_Identity, scoped to the Key_Vault resource (not the resource group or subscription)
5. WHEN the Key_Vault is created, THE Security_Module SHALL assign the "Key Vault Secrets Officer" role to admin identities (Service Principal and jumpbox Managed_Identity), scoped to the Key_Vault resource (not the resource group or subscription)
6. THE Security_Module SHALL mark all Terraform variables and outputs that contain credentials, keys, or connection strings with the `sensitive` flag to prevent their values from appearing in Terraform plan output, apply logs, or state file in cleartext
7. WHEN the Key_Vault is created, THE Security_Module SHALL disable public network access and allow access only from the virtual network subnets (snet-aks, snet-mgmt) via service endpoints or private endpoint
8. IF a Terraform variable is defined for a secret value (such as vm_admin_password), THEN THE Security_Module SHALL accept it via environment variable or pipeline secret injection and SHALL NOT define a default value in the variable declaration

### Requirement 5: Identity and Access Management

**User Story:** As a platform engineer, I want credential-free authentication between Azure services using Managed Identity with least-privilege role assignments, so that no secrets are required for inter-service communication and blast radius is minimized.

#### Acceptance Criteria

1. WHEN the Identity_Module is applied, THE Identity_Module SHALL create a User Assigned Managed_Identity named following the pattern `id-aks-{project}-{env}` using the provided project name and environment inputs
2. WHEN the Managed_Identity is created, THE Identity_Module SHALL assign the AcrPull role scoped to the specific ACR resource identified by the ACR ID input
3. WHEN the Managed_Identity is created, THE Identity_Module SHALL assign the Key Vault Secrets User role scoped to the specific Key_Vault resource identified by the Key Vault ID input
4. THE Identity_Module SHALL scope all role assignments to specific target resources rather than resource group or subscription level
5. THE Identity_Module SHALL output the managed identity ID, principal ID, and client ID as named Terraform outputs for consumption by the AKS_Module
6. THE Identity_Module SHALL NOT assign any roles beyond AcrPull on the ACR resource and Key Vault Secrets User on the Key_Vault resource to the Managed_Identity
7. IF the ACR ID or Key_Vault ID input is invalid or references a non-existent resource, THEN THE Identity_Module SHALL fail the Terraform plan or apply with an error indicating which resource reference is invalid

### Requirement 6: Administrative Jumpbox

**User Story:** As a platform engineer, I want a hardened Windows jumpbox in the management subnet configured via Ansible, so that cluster administration occurs through a controlled, auditable entry point with CIS-compliant security posture.

#### Acceptance Criteria

1. WHEN the Compute_Module is applied, THE Compute_Module SHALL create a Windows Server 2022 VM with the size defined in the `vm_size` variable, attached to the management subnet via a dedicated NIC with a private IP address
2. WHEN the VM is created, THE Compute_Module SHALL create a Standard SKU public IP and associate it with the VM's NIC for initial RDP and Ansible WinRM access
3. WHEN the VM is created, THE Compute_Module SHALL create NSG rules allowing inbound RDP (port 3389) and WinRM HTTPS (port 5986) only from the IP addresses defined in the `allowed_rdp_source_ips` input variable, with all other inbound traffic denied by default
4. WHEN the VM is created, THE Compute_Module SHALL configure a WinRM HTTPS listener on port 5986 with a self-signed certificate via a Custom Script Extension, completing before the Ansible provisioner executes
5. WHEN the VM is running and the WinRM HTTPS listener is responding on port 5986, THE Compute_Module SHALL execute the Ansible playbook via a `local-exec` provisioner from the machine running Terraform
6. WHEN Ansible runs, THE Compute_Module SHALL install kubectl, Azure CLI, and helm on the jumpbox and verify each tool is executable by running its version command
7. WHEN Ansible runs, THE Compute_Module SHALL apply CIS Microsoft Windows Server 2022 Benchmark Level 1 hardening to the jumpbox
8. IF the Ansible provisioner fails to connect or completes with a non-zero exit code, THEN THE Compute_Module SHALL mark the VM resource as tainted so that the next `terraform apply` re-provisions the VM
9. IF the `allowed_rdp_source_ips` variable is empty or not provided, THEN THE Compute_Module SHALL fail validation with an error message indicating that at least one source IP is required

### Requirement 7: CI/CD Pipeline with Security Gate

**User Story:** As a platform engineer, I want a GitHub Actions pipeline that runs Checkov security scanning as a mandatory gate before Terraform deployment, so that misconfigured infrastructure is caught before reaching Azure.

#### Acceptance Criteria

1. WHEN code is pushed to the main branch (paths: `phase 2/**`) or manually dispatched, THE Pipeline SHALL trigger execution
2. WHEN the Pipeline executes, THE Pipeline SHALL run Checkov against all `.tf` files within the `phase 2/` directory before `terraform plan`, using the Checkov configuration file (`.checkov.yaml`) if present to skip documented exceptions
3. IF Checkov detects one or more high or critical severity findings, THEN THE Pipeline SHALL fail the workflow run and skip all subsequent `terraform plan` and `terraform apply` steps
4. IF Checkov detects only medium or low severity findings and no high or critical findings, THEN THE Pipeline SHALL log the findings as warnings in the pipeline output and continue execution
5. WHEN Checkov passes with no high or critical findings, THE Pipeline SHALL run `terraform init` with backend key `{env}.terraform.tfstate` followed by `terraform plan` with the environment-specific `.tfvars` file from `environments/`
6. WHILE the Pipeline is running on the main branch, WHEN Checkov passes and `terraform plan` succeeds, THE Pipeline SHALL execute `terraform apply -auto-approve` with the same `.tfvars` file
7. WHEN running on a pull request, THE Pipeline SHALL post Checkov scan results and `terraform plan` output as a PR comment
8. IF `terraform plan` or `terraform apply` fails with a non-zero exit code, THEN THE Pipeline SHALL fail the workflow run and report the error output in the pipeline logs

### Requirement 8: Module Architecture

**User Story:** As a platform engineer, I want each Terraform module to be independently validatable and parameterized with no hardcoded values, so that modules are reusable across environments and testable in isolation.

#### Acceptance Criteria

1. THE Root_Module SHALL compose all child modules (Network, AKS, ACR, Security, Identity, Compute) and pass configuration exclusively through input variables and module output references
2. THE Root_Module SHALL express dependency ordering (Network first, then ACR and Security in parallel, then Identity, then AKS, then Compute) through implicit references from module outputs to module inputs, without using explicit `depends_on` blocks between modules
3. WHEN any child module is validated in isolation using `terraform init` followed by `terraform validate`, THE module SHALL pass without errors when provided variable values that satisfy the module's declared type constraints and validation rules
4. THE Root_Module and each child module SHALL declare all environment-varying configuration (resource names, CIDR ranges, SKUs, credentials, region) as input variables, with no literal values specific to a single environment appearing in `.tf` source files outside of variable default attributes
5. WHEN `terraform fmt -check` is run against the Root_Module directory and each child module directory, THE Root_Module and all child modules SHALL produce exit code 0 with no formatting differences reported
6. Each child module SHALL contain its own `variables.tf`, `outputs.tf`, and a `providers.tf` declaring required provider version constraints, so that `terraform init` can resolve providers independently of the Root_Module

### Requirement 9: Single-Command Deployment

**User Story:** As a platform engineer, I want all Phase 2 resources including Ansible configuration to be provisioned by a single `terraform apply` command, so that deployment is repeatable and requires no manual intervention.

#### Acceptance Criteria

1. WHEN `terraform apply -var-file="environments/dev.tfvars"` is executed, THE Root_Module SHALL provision all Phase 2 Azure resources (network, AKS, ACR, Key Vault, Managed Identity, and Jumpbox VM) and complete Ansible configuration of the Jumpbox, exiting with code 0 and requiring no interactive prompts or out-of-band commands
2. WHEN `terraform apply` is executed a second consecutive time with no configuration changes, THE Root_Module SHALL report 0 resources added, 0 changed, and 0 destroyed in the plan output, confirming idempotent behavior
3. WHEN the Pipeline runs `terraform apply`, THE Pipeline SHALL add the GitHub Actions runner's current public IP to the management subnet NSG as an inbound allow rule on port 5986 (WinRM HTTPS) before Ansible executes
4. IF Ansible provisioning completes or fails during the Pipeline run, THEN THE Pipeline SHALL remove the temporary runner IP NSG rule within the same workflow execution regardless of the outcome

### Requirement 10: Resource Naming and Tagging

**User Story:** As a platform engineer, I want consistent resource naming conventions and mandatory tagging, so that resources are identifiable, searchable, and traceable to their project and environment.

#### Acceptance Criteria

1. THE Root_Module SHALL name all resources following the patterns defined in the design document's naming convention table, where hyphen-separated resources use the format `{resource-prefix}-{project}-{env}` (e.g., `rg-devsecops-dev`, `aks-devsecops-dev`, `vnet-devsecops-dev`) and subnet resources use `snet-{purpose}-{project}-{env}` (e.g., `snet-aks-devsecops-dev`)
2. THE Root_Module SHALL apply tags `project` (set to the `project_name` variable value) and `environment` (set to the `environment` variable value) to every provisioned resource that supports Azure resource tags
3. WHEN the ACR is named, THE ACR_Module SHALL use the pattern `acr{project}{env}` (alphanumeric only, no hyphens) to comply with the Azure Container Registry naming constraint that requires globally unique alphanumeric names
4. WHEN a resource name includes the `{project}` segment, THE Root_Module SHALL substitute the value of the `project_name` input variable, and WHEN a resource name includes the `{env}` segment, THE Root_Module SHALL substitute the value of the `environment` input variable

### Requirement 11: Terraform State Management

**User Story:** As a platform engineer, I want Terraform state stored remotely with locking, so that concurrent operations are prevented and state is durable across pipeline runs.

#### Acceptance Criteria

1. THE Root_Module SHALL configure an `azurerm` backend block specifying the pre-existing storage account (`tfstatedevsecops`), resource group (`rg-terraform-state`), and container (`tfstate`) from prerequisites for remote state storage
2. WHEN `terraform init` is executed, THE Root_Module SHALL accept the state key via `-backend-config="key={env}.terraform.tfstate"` partial configuration so that each environment's state is stored in a separate blob
3. WHILE a `terraform apply` operation is in progress, THE Azure Storage backend SHALL hold a blob lease to prevent concurrent state modifications
4. IF a second `terraform apply` is attempted while a blob lease is held, THEN THE Azure Storage backend SHALL reject the operation with a lock error indicating the state is currently locked

### Requirement 12: Sensitive Value Handling

**User Story:** As a platform engineer, I want all sensitive values (passwords, secrets) excluded from source control and Terraform state output, so that credentials are never exposed in repositories, logs, or plan output.

#### Acceptance Criteria

1. THE Root_Module SHALL declare the `vm_admin_password` variable with `sensitive = true` and accept its value exclusively via the `TF_VAR_vm_admin_password` environment variable sourced from GitHub Secrets
2. IF the `TF_VAR_vm_admin_password` environment variable is not set or is empty, THEN THE Root_Module SHALL fail during `terraform plan` with a validation error indicating the required variable is missing
3. THE Root_Module SHALL apply a variable validation rule on `vm_admin_password` that rejects values shorter than 12 characters or missing at least one uppercase letter, one lowercase letter, one digit, or one special character
4. THE Root_Module SHALL mark the following outputs with the `sensitive = true` flag: `kube_config`, `vm_admin_password`, and any output whose value is derived from a variable declared as sensitive
5. THE Root_Module SHALL never store the `vm_admin_password` in `.tfvars` files or any file committed to the repository, and the `.gitignore` SHALL include a pattern that excludes all `.tfvars` files
6. WHEN the Pipeline executes, THE Pipeline SHALL inject `TF_VAR_vm_admin_password` and Azure Service Principal credentials (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`) from GitHub Secrets as masked environment variables
