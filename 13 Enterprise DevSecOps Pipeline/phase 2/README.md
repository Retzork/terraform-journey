# Phase 2: Infrastructure and Security Baseline

Phase 2 provisions the core Azure cloud infrastructure that all subsequent phases depend on. It transforms the Platform Repository's Terraform modules (created in Phase 1) into live, security-hardened Azure resources: an isolated virtual network with purpose-specific subnets, a private container registry (ACR), a secrets vault (Key Vault), a managed Kubernetes cluster (AKS), and an administrative jumpbox configured via Ansible.

This phase introduces three new tools into the pipeline — **Terraform** (declarative infrastructure provisioning), **Checkov** (pre-deployment IaC security scanning), and **Ansible** (post-deployment configuration management) — implementing the "shift-left" security principle by catching misconfigurations before deployment and enforcing CIS benchmarks on running systems.

---

## Architecture Overview

Phase 2 sits between organizational setup (Phase 1) and CI/CD automation (Phase 3) in the four-phase pipeline:

```
Phase 1: Organization ──► Phase 2: Infrastructure ──► Phase 3: CI/CD ──► Phase 4: Delivery
   (Planning & Code)        (Cloud Resources)         (Automation)        (Observability)
```

### What Phase 2 Provisions

```
Azure Subscription
└── Resource Group: rg-devsecops-{env}
    ├── Virtual Network: vnet-devsecops-{env} (10.0.0.0/16)
    │   ├── Subnet: snet-aks (10.0.1.0/24)
    │   │   └── AKS Cluster: aks-devsecops-{env}
    │   ├── Subnet: snet-app (10.0.2.0/24)
    │   │   └── ACR Private Endpoint → acrdevsecops{env}
    │   └── Subnet: snet-mgmt (10.0.3.0/24)
    │       └── Jumpbox VM: vm-jumpbox-{env}
    ├── Container Registry: acrdevsecops{env} (Premium, private-only)
    ├── Key Vault: kv-devsecops-{env} (RBAC, soft-delete, purge-protected)
    └── Managed Identity: id-aks-devsecops-{env}
        ├── AcrPull → ACR
        └── Key Vault Secrets User → Key Vault
```

### How It Fits in the Pipeline

| Consumed From Phase 1 | Produced by Phase 2 | Consumed by Phase 3/4 |
|------------------------|---------------------|----------------------|
| Platform Repository with Terraform module structure | Running AKS cluster endpoint | Workload deployment target |
| `.tfvars` environment configuration pattern | Private ACR with images accessible only from VNet | Container image registry for CI/CD |
| GitHub Actions workflow template | Key Vault with RBAC secrets access | Secret injection for pipelines |
| Branch protection governance | VNet with subnet isolation | Network boundaries for workloads |
| | Hardened jumpbox for admin access | Cluster administration entry point |

---

## Tools & Skills

| Tool Name | DevSecOps Function | Role Description |
|-----------|-------------------|------------------|
| Terraform | Infrastructure as Code | Declares all Azure resources in reusable HCL modules, enabling reproducible multi-environment provisioning from a single codebase with state management and drift detection |
| Checkov | IaC Security Scanning | Static analysis tool that scans Terraform code for security misconfigurations (CIS benchmarks, Azure best practices) before deployment — the "shift-left" gate |
| Ansible | Configuration Management | Post-deployment automation that hardens the Windows jumpbox with CIS benchmarks and installs admin tools (kubectl, az, helm) via WinRM |
| Azure Virtual Network | Network Isolation | Creates isolated network segments with subnet-level NSG rules enforcing zero-trust boundaries between AKS, application, and management tiers |
| Azure Kubernetes Service (AKS) | Container Orchestration | Managed Kubernetes cluster with Azure CNI networking, RBAC, and Managed Identity integration for secure workload execution |
| Azure Container Registry (ACR) | Private Image Registry | Premium-tier registry with public access disabled and private endpoint, ensuring container images are accessible only from within the VNet |
| Azure Key Vault | Secrets Management | Centralized vault with RBAC authorization, soft-delete, and purge protection — stores secrets consumed by AKS pods and admin tools |
| Network Security Groups (NSG) | Network Firewall | Per-subnet firewall rules with deny-all-inbound baseline, allowing only explicitly permitted traffic (RDP from known IPs, WinRM for Ansible) |
| User Assigned Managed Identity | Credential-Free Auth | Eliminates stored credentials for Azure-to-Azure communication — AKS uses this identity to pull images from ACR and read secrets from Key Vault |
| GitHub Actions | CI/CD Pipeline | Orchestrates Checkov scanning → Terraform plan → Terraform apply with security gates, dynamic NSG rules for runner access, and PR commenting |

---

## Time Estimation

| Operation | Duration | Notes |
|-----------|----------|-------|
| `terraform init` | ~30 seconds | Downloads providers, configures backend |
| `terraform plan` | ~1-2 minutes | Calculates resource changes |
| `terraform apply` | **~15-20 minutes** | AKS cluster creation (~10 min) is the bottleneck |
| Ansible provisioning | ~3-5 minutes | Runs within `terraform apply` via local-exec |
| `terraform destroy` | **~10-15 minutes** | Azure deallocates resources in parallel |
| Checkov scan | ~30 seconds | Static analysis, no Azure credentials needed |

**Breakdown of apply time:**
- Network resources (VNet, subnets, NSGs): ~2 minutes
- ACR + private endpoint + DNS zone: ~3 minutes
- Key Vault + role assignments: ~2 minutes
- AKS cluster + node pool: ~10 minutes (longest single operation)
- Jumpbox VM + Ansible: ~5 minutes

---

## Cost Estimation

Estimated Azure costs for Phase 2 resources in the `southeastasia` region:

| Resource | SKU / Tier | Daily Cost (USD) | Monthly Cost (USD) | Notes |
|----------|-----------|-----------------|-------------------|-------|
| AKS Node Pool | Standard_DS2_v2 (1 node) | ~$3.36 | ~$101 | Control plane is free; cost is for worker node VM |
| Jumpbox VM | Standard_B2s_v2 | ~$1.50 | ~$45 | Burstable VM for admin tasks |
| Container Registry | Premium | ~$1.67 | ~$50 | Required for private endpoint support |
| Key Vault | Standard | ~$0.03 | ~$1 | Per-operation pricing (minimal in dev) |
| Public IP (Jumpbox) | Standard SKU | ~$0.15 | ~$4.50 | Static IP for RDP/WinRM access |
| Virtual Network | Free | $0.00 | $0.00 | No charge for VNet or subnets |
| NSGs | Free | $0.00 | $0.00 | No charge for security groups |
| Managed Identity | Free | $0.00 | $0.00 | No charge for identity resources |
| Private Endpoint | Per endpoint | ~$0.03 | ~$1 | ACR private endpoint |
| Private DNS Zone | Per zone | ~$0.02 | ~$0.50 | privatelink.azurecr.io |
| **Total Phase 2** | | **~$6.76/day** | **~$203/month** | |

**Cost optimization tips:**
- Stop AKS cluster when not in use: `az aks stop --resource-group rg-devsecops-dev --name aks-devsecops-dev`
- Deallocate jumpbox VM: `az vm deallocate --resource-group rg-devsecops-dev --name vm-jumpbox-dev`
- Destroy all Phase 2 resources when not actively testing — recreation takes ~15-20 minutes
- Use a single AKS node (configured by default) to minimize compute costs

---

## Prerequisites

### Required Software

| Tool | Minimum Version | Install Command | Purpose |
|------|----------------|-----------------|---------|
| Terraform | 1.5+ | `winget install --id Hashicorp.Terraform` | Infrastructure provisioning |
| Azure CLI | 2.50+ | `winget install --id Microsoft.AzureCLI` | Azure authentication and verification |
| Ansible | 2.14+ | `pip install ansible` | Jumpbox configuration management |
| pywinrm | 0.4+ | `pip install pywinrm` | WinRM transport for Ansible on Windows targets |
| Python | 3.9+ | `winget install --id Python.Python.3.11` | Required for Ansible and pywinrm |
| Checkov | 3.0+ | `pip install checkov` | IaC security scanning (optional for local runs) |
| Git | 2.30+ | `winget install --id Git.Git` | Version control |

### Azure Prerequisites

1. **Azure subscription** with Contributor access
2. **Service Principal** for Terraform automation:
   ```powershell
   az ad sp create-for-rbac --name "sp-devsecops-terraform" --role Contributor --scopes /subscriptions/<subscription-id>
   ```
3. **Terraform state storage** (created in project setup):
   - Resource Group: `rg-terraform-state`
   - Storage Account: `tfstatedevsecops`
   - Container: `tfstate`

4. **Your public IP** for jumpbox RDP access (find it with `curl ifconfig.me`)

---

## Step-by-Step Instructions

### 1. Navigate to Phase 2 Directory

```powershell
cd "13 Enterprise DevSecOps Pipeline/phase 2"
```

### 2. Set Environment Variables for Sensitive Values

```powershell
# Azure Service Principal credentials
$env:ARM_CLIENT_ID = "<service-principal-app-id>"
$env:ARM_CLIENT_SECRET = "<service-principal-password>"
$env:ARM_TENANT_ID = "<tenant-id>"
$env:ARM_SUBSCRIPTION_ID = "<subscription-id>"

# VM admin password (must be 12+ chars with uppercase, lowercase, digit, special char)
$env:TF_VAR_vm_admin_password = "<your-secure-password>"
```

### 3. Verify SKU Availability

```powershell
az vm list-skus --location southeastasia --size Standard_B2s_v2 --output table
az vm list-skus --location southeastasia --size Standard_DS2_v2 --output table
```

If either SKU is unavailable, update `environments/dev.tfvars` with an available alternative.

### 4. Initialize Terraform

```powershell
terraform init -backend-config="key=dev.terraform.tfstate"
```

### 5. Run Checkov Security Scan (Optional but Recommended)

```powershell
checkov -d . --config-file .checkov.yaml
```

Verify no high or critical findings. Medium/low findings are acceptable.

### 6. Review the Plan

```powershell
terraform plan -var-file="environments/dev.tfvars"
```

Review the planned resources. Expect ~25-30 resources to be created.

### 7. Apply Infrastructure

```powershell
terraform apply -var-file="environments/dev.tfvars"
```

This single command provisions all Azure resources AND runs Ansible to configure the jumpbox. No manual intervention required.

### 8. Verify Deployment

Run the verification commands in the next section to confirm all resources are correctly provisioned.

---

## Verification Commands

After `terraform apply` completes, verify all resources:

```powershell
# Resource Group
az group show --name rg-devsecops-dev --query "{name:name, location:location, state:properties.provisioningState}" --output table

# Virtual Network and Subnets
az network vnet show --resource-group rg-devsecops-dev --name vnet-devsecops-dev --query "{name:name, addressSpace:addressSpace.addressPrefixes[0], subnets:subnets[].name}" --output json

# AKS Cluster
az aks show --resource-group rg-devsecops-dev --name aks-devsecops-dev --query "{name:name, state:provisioningState, kubernetesVersion:kubernetesVersion, nodeCount:agentPoolProfiles[0].count}" --output table

# ACR (verify private access)
az acr show --name acrdevsecopsdev --query "{name:name, publicAccess:publicNetworkAccess, sku:sku.name}" --output table

# Key Vault
az keyvault show --name kv-devsecops-dev --query "{name:name, softDelete:properties.enableSoftDelete, purgeProtection:properties.enablePurgeProtection, rbac:properties.enableRbacAuthorization}" --output table

# Jumpbox VM
az vm show --resource-group rg-devsecops-dev --name vm-jumpbox-dev --show-details --query "{name:name, state:powerState, publicIp:publicIps, privateIp:privateIps}" --output table

# Managed Identity
az identity show --resource-group rg-devsecops-dev --name id-aks-devsecops-dev --query "{name:name, clientId:clientId, principalId:principalId}" --output table

# NSG Rules (verify deny-all baseline)
az network nsg show --resource-group rg-devsecops-dev --name nsg-aks-devsecops-dev --query "securityRules[].{name:name, priority:priority, access:access, direction:direction}" --output table
```

### Expected Results

| Resource | Expected State |
|----------|---------------|
| Resource Group | Succeeded |
| VNet | 10.0.0.0/16 with 3 subnets |
| AKS | Succeeded, Running, 1 node |
| ACR | publicNetworkAccess: Disabled |
| Key Vault | softDelete: true, purgeProtection: true, rbac: true |
| Jumpbox VM | VM running, public IP assigned |
| Managed Identity | Created with clientId and principalId |

---

## Educational Context

### Terraform — Infrastructure as Code

**What it does:** Terraform reads `.tf` files written in HCL (HashiCorp Configuration Language) and translates them into Azure API calls. It maintains a state file that tracks what resources exist, enabling it to calculate the minimal set of changes needed on each `apply`.

**Why it's needed in DevSecOps:** Manual infrastructure provisioning is error-prone, undocumented, and unrepeatable. Terraform makes infrastructure version-controlled, reviewable, and auditable — the same governance applied to application code now applies to cloud resources. Every change goes through a PR, gets scanned by Checkov, and is traceable in Git history.

**How it connects to Phase 3/4:** Phase 3's GitHub Actions workflows consume Terraform outputs (AKS endpoint, ACR login server, Key Vault name) to configure deployment targets. Phase 4's monitoring resources reference the AKS cluster and VNet created here.

### Checkov — IaC Security Scanning

**What it does:** Checkov statically analyzes Terraform code against 1000+ security policies (CIS benchmarks, Azure best practices, NIST frameworks). It runs without Azure credentials — purely code analysis.

**Why it's needed in DevSecOps:** "Shift-left" means catching security issues as early as possible. Checkov finds misconfigurations (public storage accounts, unencrypted databases, overly permissive network rules) in code review — before resources are created. This is cheaper and faster than finding issues in production.

**How it connects to Phase 3/4:** Phase 3 extends security scanning to application code (SonarQube for SAST, Snyk for SCA, Trivy for container images). Checkov handles infrastructure; Phase 3 tools handle application code. Together they provide full-stack security coverage.

### Ansible — Configuration Management

**What it does:** Ansible connects to the Windows jumpbox via WinRM and executes playbooks that install software (kubectl, Azure CLI, helm) and apply CIS hardening (disable unnecessary services, configure audit policies, set security registry keys).

**Why it's needed in DevSecOps:** Provisioning a VM is not enough — it must be configured securely. Ansible ensures every jumpbox is identically hardened regardless of who deploys it or when. CIS benchmarks are industry-standard security baselines that reduce attack surface.

**How it connects to Phase 3/4:** The jumpbox configured by Ansible is the administrative entry point for Phase 3 (deploying workloads to AKS) and Phase 4 (accessing monitoring dashboards). kubectl, az, and helm installed here are the tools used to manage the cluster.

### Azure Virtual Network — Network Isolation

**What it does:** Creates an isolated network boundary (10.0.0.0/16) with three purpose-specific subnets, each protected by its own NSG with deny-all-inbound baseline rules.

**Why it's needed in DevSecOps:** Zero-trust networking means no resource trusts another by default. Subnet segmentation limits blast radius — a compromised pod in the AKS subnet cannot directly reach the management jumpbox. NSG rules enforce least-privilege traffic flow.

**How it connects to Phase 3/4:** Phase 3 workloads deploy into the AKS subnet and communicate with ACR via the private endpoint in the app subnet. Phase 4 monitoring agents collect data from all subnets.

### Azure Kubernetes Service (AKS) — Container Orchestration

**What it does:** Managed Kubernetes cluster that runs containerized workloads with automated scaling, self-healing, and Azure security integration. Uses Azure CNI so pods get real VNet IPs.

**Why it's needed in DevSecOps:** Containers provide consistent, isolated execution environments. AKS adds managed control plane, automatic patching, and integration with Azure RBAC and Managed Identity — reducing operational burden while maintaining security posture.

**How it connects to Phase 3/4:** Phase 3 deploys scanned container images to this cluster via GitHub Actions. Phase 4 collects metrics and logs from AKS via the OMS agent enabled in this phase.

### Azure Container Registry (ACR) — Private Image Registry

**What it does:** Stores container images with public access completely disabled. Only accessible from within the VNet via private endpoint and private DNS zone.

**Why it's needed in DevSecOps:** Supply-chain security requires controlling where images come from. A private registry ensures only authorized, scanned images are available for deployment. No external actor can push malicious images or pull proprietary code.

**How it connects to Phase 3/4:** Phase 3's CI/CD pipeline builds images, scans them with Trivy, and pushes to this ACR. AKS pulls images from ACR using the Managed Identity's AcrPull role — no credentials stored anywhere.

### Azure Key Vault — Secrets Management

**What it does:** Centralized vault storing secrets, keys, and certificates with RBAC access control, soft-delete (90-day recovery), and purge protection.

**Why it's needed in DevSecOps:** Hardcoded secrets in code or config files are the #1 cause of credential leaks. Key Vault eliminates this by providing a secure, auditable, access-controlled store. RBAC ensures only authorized identities can read specific secrets.

**How it connects to Phase 3/4:** Phase 3 pipelines inject secrets from Key Vault into deployment manifests. AKS pods access secrets via the CSI Secrets Store driver. Phase 4 monitors Key Vault access patterns for anomalies.

### Managed Identity — Credential-Free Authentication

**What it does:** Azure-native identity that authenticates between services without storing credentials. AKS uses this identity to pull images from ACR and read secrets from Key Vault.

**Why it's needed in DevSecOps:** Credentials that don't exist can't be leaked. Managed Identity eliminates the need for service account passwords, connection strings, or API keys for Azure-to-Azure communication. Role assignments follow least-privilege (AcrPull, not Contributor).

**How it connects to Phase 3/4:** Phase 3 workloads inherit the AKS cluster's managed identity for Azure resource access. Phase 4 monitoring uses the same identity pattern for secure data collection.

### GitHub Actions — CI/CD Pipeline

**What it does:** Automates the deployment workflow: Checkov scan → Terraform plan → Terraform apply, with dynamic NSG rules for runner access and PR commenting for visibility.

**Why it's needed in DevSecOps:** Manual deployments bypass security gates. The pipeline enforces that every infrastructure change passes Checkov scanning before reaching Azure. Failed scans block deployment — no exceptions.

**How it connects to Phase 3/4:** Phase 3 extends this pipeline pattern to application deployments (build → scan → deploy). The same GitHub Actions infrastructure handles both infrastructure and application CI/CD.

---

## Module Architecture

Phase 2 uses six Terraform modules composed by a root module:

```
phase 2/
├── main.tf                          # Root module composing all child modules
├── variables.tf                     # All root variable declarations
├── outputs.tf                       # Root outputs (consumed by Phase 3/4)
├── providers.tf                     # AzureRM provider + backend configuration
├── environments/
│   └── dev.tfvars                   # Development environment values
├── modules/
│   ├── network/                     # VNet, subnets, NSGs
│   ├── aks/                         # Kubernetes cluster
│   ├── acr/                         # Container registry + private endpoint
│   ├── security/                    # Key Vault + role assignments
│   ├── identity/                    # Managed Identity + role assignments
│   └── compute/                     # Jumpbox VM + Ansible provisioning
├── ansible/
│   ├── ansible.cfg                  # WinRM connection settings
│   ├── inventory/hosts.yml.tpl      # Dynamic inventory template
│   ├── playbooks/jumpbox-config.yml # Main playbook
│   └── roles/
│       ├── admin-tools/tasks/       # kubectl, az, helm installation
│       └── cis-hardening/tasks/     # CIS Windows Server 2022 benchmarks
├── .github/workflows/
│   └── terraform-phase2.yml         # CI/CD pipeline with Checkov gate
├── .checkov.yaml                    # Security scan configuration
└── tests/                           # Validation and property test scripts
```

### Module Dependency Order

Terraform resolves dependencies automatically through output-to-input references:

```
1. Network          (no dependencies)
2. ACR + Security   (depend on Network outputs)
3. Identity         (depends on ACR + Security outputs)
4. AKS             (depends on Network + Identity outputs)
5. Compute         (depends on Network, runs Ansible after VM creation)
```

No explicit `depends_on` blocks are used between modules.

---

## Troubleshooting

### "SkuNotAvailable" — VM SKU Not Available in Region

**Symptom:** `terraform apply` fails with error mentioning "SkuNotAvailable" for `Standard_B2s_v2` or `Standard_DS2_v2`.

**Cause:** The requested VM size is not available or is restricted in the `southeastasia` region for your subscription.

**Resolution:**
```powershell
# Check availability
az vm list-skus --location southeastasia --size Standard_B2s_v2 --output table

# If unavailable, find alternatives
az vm list-skus --location southeastasia --resource-type virtualMachines --query "[?restrictions[0].type!='Location'].{Name:name, Tier:tier}" --output table
```
Update `vm_size` in `environments/dev.tfvars` to an available SKU.

### "VaultAlreadyExists" — Key Vault Soft Delete Conflict

**Symptom:** `terraform apply` fails with "ConflictError" or "VaultAlreadyExists" when creating Key Vault.

**Cause:** A previously deleted Key Vault with the same name exists in soft-deleted state (retained for 90 days).

**Resolution:**
```powershell
# List soft-deleted vaults
az keyvault list-deleted --query "[].{name:name, location:properties.location}" --output table

# Purge the conflicting vault
az keyvault purge --name kv-devsecops-dev --location southeastasia
```
Then re-run `terraform apply`.

### WinRM Connection Timeout — Ansible Cannot Reach Jumpbox

**Symptom:** `terraform apply` hangs or fails at the Ansible provisioning step with "connection refused" or timeout errors.

**Cause:** The NSG does not allow WinRM (port 5986) from the machine running Terraform, or the WinRM listener is not yet configured on the VM.

**Resolution:**
1. Verify your public IP is in `allowed_rdp_source_ips` in `dev.tfvars`
2. Check NSG rules allow port 5986 from your IP:
   ```powershell
   az network nsg rule list --resource-group rg-devsecops-dev --nsg-name nsg-mgmt-devsecops-dev --output table
   ```
3. Verify the VM's Custom Script Extension completed (it configures WinRM):
   ```powershell
   az vm extension list --resource-group rg-devsecops-dev --vm-name vm-jumpbox-dev --output table
   ```
4. If the extension failed, taint and re-apply:
   ```powershell
   terraform taint 'module.compute.azurerm_windows_virtual_machine.jumpbox'
   terraform apply -var-file="environments/dev.tfvars"
   ```

### ACR DNS Resolution Failure — Image Pulls Fail

**Symptom:** AKS pods fail to start with "ImagePullBackOff" and events show "name resolution failure" for `acrdevsecopsdev.azurecr.io`.

**Cause:** The private DNS zone is not linked to the VNet, or the A record is missing/incorrect.

**Resolution:**
```powershell
# Verify private DNS zone exists and is linked
az network private-dns zone show --resource-group rg-devsecops-dev --name privatelink.azurecr.io

# Verify VNet link
az network private-dns link vnet list --resource-group rg-devsecops-dev --zone-name privatelink.azurecr.io --output table

# Verify A record points to private endpoint IP
az network private-dns record-set a list --resource-group rg-devsecops-dev --zone-name privatelink.azurecr.io --output table
```

### "InsufficientSubnetSize" — AKS Subnet Too Small

**Symptom:** AKS cluster creation fails or pod scheduling fails with subnet exhaustion errors.

**Cause:** Azure CNI requires one IP per pod. The default `/24` subnet provides 251 usable IPs, which may be insufficient if node count or pod density increases.

**Resolution:** Increase `subnet_aks_cidr` in `environments/dev.tfvars` to a larger range (e.g., `10.0.0.0/22` for 1019 IPs). Then re-apply.

### GitHub Actions Runner IP Not in NSG

**Symptom:** Pipeline's Ansible step fails because the ephemeral GitHub Actions runner IP is not allowed through the NSG.

**Cause:** GitHub-hosted runners have dynamic IPs that change on every run. Static NSG rules cannot accommodate this.

**Resolution:** The pipeline workflow includes steps to dynamically add/remove the runner's IP:
```yaml
# The workflow handles this automatically:
# 1. Gets runner IP: curl -s ifconfig.me
# 2. Adds temporary NSG rule for WinRM access
# 3. Runs terraform apply
# 4. Removes temporary NSG rule (always, even on failure)
```
If running locally, ensure your current IP is in `allowed_rdp_source_ips`.

### Terraform State Lock Error

**Symptom:** `terraform apply` fails with "Error acquiring the state lock" or "state is currently locked".

**Cause:** A previous `terraform apply` was interrupted, leaving a blob lease on the state file.

**Resolution:**
```powershell
# Force unlock (use the lock ID from the error message)
terraform force-unlock <lock-id>
```
Only use this if you are certain no other apply is running.

---

## Teardown

To destroy all Phase 2 resources:

```powershell
cd "phase 2"
terraform destroy -var-file="environments/dev.tfvars"
```

**Important notes:**
- Key Vault enters soft-deleted state (retained 90 days). Purge it if you plan to re-deploy with the same name.
- AKS cluster deletion takes ~5 minutes.
- Ensure no Phase 3/4 resources depend on Phase 2 before destroying.

---

## What Comes Next

Phase 2 outputs feed directly into Phase 3 (CI/CD):

- The **AKS cluster** is the deployment target for containerized workloads built in Phase 3
- The **ACR** stores container images that Phase 3's pipeline builds, scans (Trivy), and pushes
- The **Key Vault** provides secrets that Phase 3 pipelines inject into deployments
- The **Jumpbox** is the admin entry point for managing AKS and debugging deployments
- The **Managed Identity** pattern established here extends to workload identities in Phase 3
- The **Checkov scanning** pattern extends to Trivy (containers), SonarQube (code), and Snyk (dependencies) in Phase 3
