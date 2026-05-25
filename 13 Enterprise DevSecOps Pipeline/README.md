# Azure DevSecOps Pipeline Architecture

A four-phase enterprise DevSecOps pipeline demonstrating security-integrated delivery on Azure using 16 industry-standard tools. This project provisions organizational foundations, cloud infrastructure, CI/CD automation, and observability — each phase building on the outputs of the previous one.

## Architecture Overview

The pipeline follows a sequential four-phase model where each phase produces artifacts consumed by the next:

```
Phase 1: Organization ──► Phase 2: Infrastructure ──► Phase 3: CI/CD ──► Phase 4: Delivery
   (Planning & Code)        (Cloud Resources)         (Automation)        (Observability)
```

### Phase Flow and Input/Output Relationships

```
┌─────────────────────────┐
│  Phase 1: Organization  │
│  ─────────────────────  │
│  GitHub Projects        │
│  GitHub Repositories    │
│                         │
│  OUTPUT:                │
│  • Project board with   │
│    phase tracking       │
│  • Platform repo with   │
│    Terraform modules    │
│  • Workload repo with   │
│    app source scaffold  │
│  • Branch protection    │
│    governance           │
└───────────┬─────────────┘
            │ Repos + IaC modules
            ▼
┌─────────────────────────┐
│ Phase 2: Infrastructure │
│ ─────────────────────── │
│  Terraform              │
│  Checkov (IaC scanning) │
│  Ansible (VM hardening) │
│  Azure Virtual Network  │
│  Azure Kubernetes Svc   │
│  Azure Container Reg.   │
│  Azure Key Vault        │
│  Managed Identity       │
│                         │
│  INPUT:                 │
│  • Platform repo modules│
│  • .tfvars environment  │
│    configuration        │
│                         │
│  OUTPUT:                │
│  • Provisioned VNet     │
│    with subnet isolation│
│  • Running AKS cluster  │
│  • Private ACR with     │
│    private endpoint     │
│  • Key Vault with       │
│    RBAC secrets access  │
│  • Hardened jumpbox VM  │
│    (CIS Level 1)        │
└───────────┬─────────────┘
            │ Live infrastructure endpoints
            ▼
┌─────────────────────────┐
│     Phase 3: CI/CD      │
│  ─────────────────────  │
│  GitHub Actions         │
│  Trivy                  │
│  SonarQube              │
│  Snyk                   │
│                         │
│  INPUT:                 │
│  • AKS cluster endpoint │
│  • Key Vault secrets    │
│  • Workload repo source │
│                         │
│  OUTPUT:                │
│  • Scanned container    │
│    images               │
│  • Validated code       │
│    quality              │
│  • Deployed workloads   │
│    on AKS               │
└───────────┬─────────────┘
            │ Running workloads + telemetry
            ▼
┌─────────────────────────┐
│    Phase 4: Delivery    │
│  ─────────────────────  │
│  Azure Monitor          │
│  Log Analytics          │
│                         │
│  INPUT:                 │
│  • AKS cluster metrics  │
│  • Application logs     │
│  • Pipeline run data    │
│                         │
│  OUTPUT:                │
│  • Dashboards           │
│  • Alerts               │
│  • Audit trail          │
└─────────────────────────┘
```

## Tools

This architecture uses 16 tools spanning project management, infrastructure, security, and observability:

1. **GitHub Projects** — Agile project management board that tracks tasks across all four DevSecOps deployment phases.
2. **GitHub Repositories** — Source control platform hosting infrastructure-as-code and application workloads with branch governance.
3. **Terraform** — Infrastructure-as-code tool that declaratively provisions and manages Azure cloud resources from version-controlled configurations.
4. **Checkov** — Static analysis tool for infrastructure-as-code that detects security misconfigurations before deployment, acting as a mandatory pipeline gate.
5. **Ansible** — Configuration management tool that automates post-deployment jumpbox hardening (CIS benchmarks) and administrative tool installation via WinRM.
6. **Azure Virtual Network** — Network isolation layer that segments workloads into subnets with controlled traffic flow between tiers.
7. **Azure Kubernetes Service (AKS)** — Managed container orchestration platform that runs application workloads with built-in scaling and security policies.
8. **Azure Container Registry (ACR)** — Private container image registry accessible only via private endpoint within the VNet, enforcing zero-trust image access.
9. **Azure Key Vault** — Centralized secrets management service that stores and controls access to certificates, keys, and connection strings.
10. **Azure Managed Identity** — Credential-free authentication mechanism enabling Azure-to-Azure communication without storing secrets (AKS uses it for ACR pulls and Key Vault access).
11. **Network Security Groups (NSG)** — Per-subnet firewall rules with deny-all inbound defaults, allowing only explicitly permitted traffic.
12. **GitHub Actions** — CI/CD automation engine that orchestrates Checkov scanning and Terraform deployment (Phase 2) and builds, tests, scans, and deploys code (Phase 3).
13. **Trivy** — Container vulnerability scanner that detects OS and library vulnerabilities in Docker images before deployment.
14. **SonarQube** — Static application security testing (SAST) tool that analyzes source code for bugs, code smells, and security vulnerabilities.
15. **Snyk** — Software composition analysis (SCA) tool that identifies known vulnerabilities in open-source dependencies.
16. **Azure Monitor / Log Analytics** — Observability platform that collects metrics, logs, and traces for real-time alerting and post-incident analysis.

## Tools & Skills

| Tool Name | DevSecOps Function | Phase Introduced | Role Description |
|---|---|---|---|
| GitHub Projects | Project Management | Phase 1: Organization | Provides agile board tracking for tasks, milestones, and phase progress across the entire pipeline lifecycle |
| GitHub Repositories | Source Control | Phase 1: Organization | Hosts versioned infrastructure code and application source with branch protection enforcing code review governance |
| Terraform | Infrastructure as Code | Phase 2: Infrastructure | Declares cloud resources in reusable modules, enabling reproducible multi-environment provisioning from a single codebase |
| Checkov | IaC Security Scanning | Phase 2: Infrastructure | Static analysis tool that detects security misconfigurations in Terraform code before deployment — mandatory pipeline gate |
| Ansible | Configuration Management | Phase 2: Infrastructure | Post-deployment automation that hardens the jumpbox VM with CIS benchmarks and installs administrative tools (kubectl, az, helm) |
| Azure Virtual Network | Network Isolation | Phase 2: Infrastructure | Creates isolated network segments with subnet-level access controls to enforce zero-trust boundaries between workload tiers |
| Azure Kubernetes Service | Container Orchestration | Phase 2: Infrastructure | Runs containerized workloads with automated scaling, self-healing, and integration with Azure security services |
| Azure Container Registry | Container Image Storage | Phase 2: Infrastructure | Private container registry with no public access, accessible only via private endpoint within the VNet |
| Azure Key Vault | Secrets Management | Phase 2: Infrastructure | Stores sensitive credentials and certificates with RBAC-controlled access, eliminating hardcoded secrets from code and pipelines |
| Azure Managed Identity | Credential-Free Auth | Phase 2: Infrastructure | Enables Azure-to-Azure authentication without storing credentials — AKS uses it for ACR pulls and Key Vault access |
| Network Security Groups | Network Firewall | Phase 2: Infrastructure | Per-subnet firewall rules with deny-all defaults, allowing only explicitly permitted traffic (RDP from known IPs, WinRM for Ansible) |
| GitHub Actions | CI/CD Automation | Phase 2/3: Infrastructure & CI/CD | Orchestrates Checkov scanning and Terraform deployment in Phase 2; build, test, scan, and deploy workflows in Phase 3 |
| Trivy | Container Vulnerability Scanning | Phase 3: CI/CD | Scans container images for known CVEs in OS packages and application libraries, blocking deployment of vulnerable images |
| SonarQube | Static Application Security Testing | Phase 3: CI/CD | Performs deep source code analysis to detect security vulnerabilities, bugs, and maintainability issues before merge |
| Snyk | Software Composition Analysis | Phase 3: CI/CD | Monitors third-party dependencies for known vulnerabilities and license compliance risks with automated fix suggestions |
| Azure Monitor / Log Analytics | Observability | Phase 4: Delivery | Aggregates metrics, logs, and distributed traces into unified dashboards with alerting for security and performance anomalies |

## Phases

### Phase 1: Organization

**Tools:** GitHub Projects, GitHub Repositories

**Purpose:** Establish the project management and source control foundation that all subsequent phases depend on.

**Outputs consumed by Phase 2:**
- Platform Repository containing Terraform modules for infrastructure provisioning
- Workload Repository scaffold ready for application code
- Branch protection rules enforcing code review before infrastructure changes

### Phase 2: Infrastructure

**Tools:** Terraform, Checkov, Ansible, Azure Virtual Network, Azure Kubernetes Service, Azure Container Registry, Azure Key Vault, Managed Identity, GitHub Actions

**Purpose:** Provision the cloud infrastructure that hosts workloads and stores secrets, using the IaC modules from Phase 1. Checkov enforces security compliance before deployment (shift-left), and Ansible hardens the administrative jumpbox post-deployment.

**Security approach:**
- **Pre-deployment:** Checkov scans all Terraform files for misconfigurations (mandatory gate — blocks on high/critical findings)
- **Network isolation:** Private ACR with no public access, NSGs with deny-all defaults, subnet segmentation
- **Identity:** User Assigned Managed Identity with least-privilege role assignments (AcrPull, Key Vault Secrets User)
- **Post-deployment:** Ansible applies CIS Windows Server 2022 Benchmark Level 1 hardening to the jumpbox

**Inputs from Phase 1:**
- Platform Repository Terraform modules and environment `.tfvars` files

**Outputs consumed by Phase 3:**
- Running AKS cluster endpoint for workload deployment
- Private ACR for secure container image storage (accessible only from within VNet)
- Key Vault instance with stored secrets for pipeline authentication
- Virtual Network with subnet isolation for secure communication
- Hardened jumpbox VM as the sole administrative entry point to the cluster

### Phase 3: CI/CD

**Tools:** GitHub Actions, Trivy, SonarQube, Snyk

**Purpose:** Automate the build, security scan, and deployment pipeline that delivers code from the Workload Repository to the AKS cluster.

**Inputs from Phase 2:**
- AKS cluster credentials and endpoint
- Key Vault secrets for service authentication
- Network configuration for secure deployment targets

**Outputs consumed by Phase 4:**
- Deployed application workloads emitting logs and metrics
- Pipeline execution data and security scan results

### Phase 4: Delivery

**Tools:** Azure Monitor, Log Analytics

**Purpose:** Provide observability into the running system, closing the feedback loop with dashboards, alerts, and audit trails.

**Inputs from Phase 3:**
- Application telemetry from deployed workloads
- AKS cluster health metrics
- Pipeline and security scan audit data


## Two-Repository Structure

This architecture separates concerns into two dedicated repositories:

| Repository | Naming Pattern | Purpose |
|---|---|---|
| **Platform Repository** | `<prefix>-platform-infrastructure` | Stores reusable Terraform modules for provisioning Azure cloud resources |
| **Workload Repository** | `<prefix>-workload` | Stores application source code, Dockerfiles, and CI/CD workflow definitions |

### Separation of Concerns

Infrastructure code and application code evolve at different rates, have different review requirements, and carry different risk profiles. Keeping them in separate repositories provides:

- **Independent release cycles** — infrastructure changes deploy without touching application code, and vice versa
- **Distinct access controls** — platform engineers manage infrastructure modules while application developers own workload code
- **Isolated blast radius** — a broken application build never blocks infrastructure provisioning
- **Clear ownership boundaries** — branch protection and review policies can be tailored per repository

### Platform Repository Reuse via `.tfvars`

The Platform Repository is designed as a single codebase that supports multiple environments without code duplication. This is achieved through two mechanisms:

1. **Environment-specific `.tfvars` files** — Each environment (dev, staging, production) is defined by a single file in the `environments/` directory (e.g., `environments/project-alpha-dev.tfvars`). Adding a new environment requires only creating a new `.tfvars` file with the desired variable values — no module source code or root configuration changes needed.

2. **Dynamic state isolation** — The pipeline injects a unique Terraform state key per environment at runtime (`terraform init -backend-config="key=<env>.terraform.tfstate"`). This ensures each environment maintains its own state file, preventing resource conflicts between deployments from the same codebase.

Together, these patterns mean provisioning a new, fully isolated DevSecOps environment requires only:
- Adding a `.tfvars` file to `environments/`
- Running the pipeline with the corresponding environment name

No modifications to module source code, root configuration, or pipeline definitions are required.

## Pipeline Diagram

The following diagram illustrates the end-to-end DevSecOps pipeline flow from developer commit through production observability, labeling all four phases and key tools at each stage:

```
 ┌─────────────────────────────────────────────────────────────────────────────────────────────┐
 │                        AZURE DEVSECOPS PIPELINE ARCHITECTURE                                │
 └─────────────────────────────────────────────────────────────────────────────────────────────┘

   COMMIT                                                                          OBSERVABILITY
     │                                                                                   ▲
     ▼                                                                                   │
 ╔═══════════════════╗     ╔═══════════════════╗     ╔═══════════════════╗     ╔═══════════════════╗
 ║  PHASE 1          ║     ║  PHASE 2          ║     ║  PHASE 3          ║     ║  PHASE 4          ║
 ║  Organization     ║     ║  Infrastructure   ║     ║  CI/CD            ║     ║  Delivery         ║
 ╠═══════════════════╣     ╠═══════════════════╣     ╠═══════════════════╣     ╠═══════════════════╣
 ║                   ║     ║                   ║     ║                   ║     ║                   ║
 ║ ┌───────────────┐ ║     ║ ┌───────────────┐ ║     ║ ┌───────────────┐ ║     ║ ┌───────────────┐ ║
 ║ │GitHub Projects│ ║     ║ │  Terraform    │ ║     ║ │GitHub Actions │ ║     ║ │Azure Monitor  │ ║
 ║ └───────────────┘ ║     ║ └───────────────┘ ║     ║ └───────────────┘ ║     ║ └───────────────┘ ║
 ║ ┌───────────────┐ ║     ║ ┌───────────────┐ ║     ║ ┌───────────────┐ ║     ║ ┌───────────────┐ ║
 ║ │GitHub Repos   │ ║     ║ │   Checkov     │ ║     ║ │    Trivy      │ ║     ║ │Log Analytics  │ ║
 ║ └───────────────┘ ║     ║ └───────────────┘ ║     ║ └───────────────┘ ║     ║ └───────────────┘ ║
 ║                   ║     ║ ┌───────────────┐ ║     ║ ┌───────────────┐ ║     ║                   ║
 ║                   ║     ║ │   Ansible     │ ║     ║ │  SonarQube    │ ║     ║                   ║
 ║                   ║     ║ └───────────────┘ ║     ║ └───────────────┘ ║     ║                   ║
 ║                   ║     ║ ┌───────────────┐ ║     ║ ┌───────────────┐ ║     ║                   ║
 ║                   ║     ║ │  Azure VNet   │ ║     ║ │     Snyk      │ ║     ║                   ║
 ║                   ║     ║ └───────────────┘ ║     ║ └───────────────┘ ║     ║                   ║
 ║                   ║     ║ ┌───────────────┐ ║     ║                   ║     ║                   ║
 ║                   ║     ║ │   Azure AKS   │ ║     ║                   ║     ║                   ║
 ║                   ║     ║ └───────────────┘ ║     ║                   ║     ║                   ║
 ║                   ║     ║ ┌───────────────┐ ║     ║                   ║     ║                   ║
 ║                   ║     ║ │  Azure ACR    │ ║     ║                   ║     ║                   ║
 ║                   ║     ║ └───────────────┘ ║     ║                   ║     ║                   ║
 ║                   ║     ║ ┌───────────────┐ ║     ║                   ║     ║                   ║
 ║                   ║     ║ │Azure Key Vault│ ║     ║                   ║     ║                   ║
 ║                   ║     ║ └───────────────┘ ║     ║                   ║     ║                   ║
 ║                   ║     ║ ┌───────────────┐ ║     ║                   ║     ║                   ║
 ║                   ║     ║ │Managed Identity║     ║                   ║     ║                   ║
 ║                   ║     ║ └───────────────┘ ║     ║                   ║     ║                   ║
 ║                   ║     ║                   ║     ║                   ║     ║                   ║
 ╚═════════╤═════════╝     ╚═════════╤═════════╝     ╚═════════╤═════════╝     ╚═══════════════════╝
           │                         │                         │
           │  Repos + IaC modules    │  Live infrastructure    │  Deployed workloads
           ├─────────────────────────┤─────────────────────────┤
           ▼                         ▼                         ▼

 ──────────────────────────────────────────────────────────────────────────────────────────────────►
                                    FLOW DIRECTION
```

### Diagram Key

| Phase | Primary Function | Key Tool(s) | Handoff to Next Phase |
|---|---|---|---|
| Phase 1: Organization | Planning and code management | GitHub Projects, GitHub Repos | Repositories with IaC modules and app scaffold |
| Phase 2: Infrastructure | Cloud resource provisioning + security scanning | Terraform, Checkov, Ansible, AKS, VNet, ACR, Key Vault, Managed Identity | Live infrastructure endpoints, secrets, and hardened admin access |
| Phase 3: CI/CD | Security scanning and deployment | GitHub Actions, Trivy, SonarQube, Snyk | Deployed and validated workloads |
| Phase 4: Delivery | Monitoring and observability | Azure Monitor, Log Analytics | Dashboards, alerts, and audit trails |

## Phase 1 Tool Details

### GitHub Projects

**Purpose:** GitHub Projects (v2) serves as the agile planning backbone for the entire DevSecOps pipeline. It provides a Kanban-style board with custom fields that track work items across all four deployment phases, giving visibility into what has been completed, what is in progress, and what remains.

**DevSecOps Relevance:** In enterprise DevSecOps, traceability between planning and execution is critical. GitHub Projects connects tasks to commits, pull requests, and deployments — creating an audit trail that demonstrates governance and accountability. Security-related tasks (vulnerability remediation, compliance checks) are tracked alongside feature work, ensuring security is never an afterthought.

**Output consumed by subsequent phases:** Phase 2 (Infrastructure) and Phase 3 (CI/CD) consume the project board as a tracking surface. As infrastructure is provisioned and pipelines are configured, task items on the board are updated to reflect progress. The board's Phase field allows filtering to see only the work relevant to the current deployment stage.

### GitHub Repositories

**Purpose:** GitHub Repositories provide version-controlled storage for all project artifacts — infrastructure-as-code configurations (Platform Repository) and application source code (Workload Repository). The two-repository separation enforces a clear boundary between infrastructure concerns and application concerns.

**DevSecOps Relevance:** Repository-level controls are the first line of defense in a DevSecOps pipeline. Branch protection rules enforce code review before changes reach production, required status checks gate merges on passing security scans, and commit history provides a complete audit trail. Separating infrastructure from workload code ensures that changes to cloud resources go through a different review process than application changes — matching enterprise access control patterns.

**Output consumed by subsequent phases:**
- **Phase 2 (Infrastructure)** directly consumes the Platform Repository's Terraform modules and `.tfvars` files to provision Azure resources (VNet, AKS, Key Vault).
- **Phase 3 (CI/CD)** consumes both repositories: the Platform Repository's `.github/workflows/` pipeline definitions and the Workload Repository's application source code, Dockerfiles, and CI workflow definitions.

---

## Time Estimation

Estimated `terraform apply` and `terraform destroy` durations for each phase:

| Phase | Apply Time | Destroy Time | Notes |
|-------|-----------|--------------|-------|
| Phase 1: Organization | ~5 minutes | ~2 minutes | GitHub API operations (repo creation, board setup, branch protection). No cloud resources. |
| Phase 2: Infrastructure | ~15-20 minutes | ~10-15 minutes | AKS cluster creation (~10 min) is the bottleneck. Ansible jumpbox provisioning adds ~3-5 min. |
| Phase 3: CI/CD | ~10 minutes | ~5 minutes | Pipeline configuration, webhook setup, and initial workflow registration. |
| Phase 4: Delivery | ~5 minutes | ~3 minutes | Monitoring workspace, alert rules, and dashboard configuration. |

**Total pipeline deployment:** ~35-40 minutes from zero to fully operational.

**Notes:**
- Phase 1 uses GitHub CLI (`gh`) rather than Terraform, so times reflect script execution rather than `terraform apply`.
- AKS cluster provisioning in Phase 2 is the longest single operation. Azure provisions the control plane, node pools, and networking components sequentially.
- Phase 2 Ansible provisioning (jumpbox CIS hardening + tool installation) runs as a `local-exec` provisioner after the VM is created. WinRM connectivity setup adds ~1-2 minutes before Ansible tasks begin.
- Destroy times are generally shorter because Azure can deallocate resources in parallel.
- Phase 2 destroy may take longer if Key Vault soft-delete is enabled (vault enters soft-deleted state rather than being immediately purged).

### Phase 2 Detailed Timing Breakdown

| Operation | Duration | Details |
|-----------|----------|---------|
| `terraform init` | ~10-15 seconds | Downloads azurerm provider, configures backend |
| Checkov security scan | ~30 seconds | Static analysis of all `.tf` files |
| VNet + Subnets + NSGs | ~1-2 minutes | Network foundation provisioning |
| ACR + Private Endpoint + DNS | ~2-3 minutes | Container registry with private networking |
| Key Vault + Role Assignments | ~1-2 minutes | Secrets vault with RBAC configuration |
| Managed Identity + Roles | ~1 minute | Identity creation and role scoping |
| AKS Cluster | ~8-10 minutes | Control plane + node pool provisioning (longest operation) |
| Jumpbox VM + Public IP + NIC | ~2-3 minutes | Windows Server 2022 VM creation |
| WinRM Setup (Custom Script Extension) | ~1-2 minutes | Self-signed certificate and HTTPS listener |
| Ansible Provisioning | ~3-5 minutes | CIS hardening + kubectl/az/helm installation |
| **Total Apply** | **~15-20 minutes** | End-to-end single `terraform apply` |
| **Total Destroy** | **~10-15 minutes** | Parallel resource deallocation |

---

## Cost Estimation

Estimated Azure costs for running the full pipeline infrastructure (Phase 2-4 resources):

### Phase 2: Infrastructure Resources

| Resource | SKU / Tier | Daily Cost (USD) | Monthly Cost (USD) | Notes |
|----------|-----------|-----------------|-------------------|-------|
| AKS Cluster (nodes) | Standard_DS2_v2 (1 node) | ~$3.36 | ~$101 | Control plane is free; cost is for worker node VM. Single node for learning. |
| Jumpbox VM | Standard_B2s_v2 | ~$1.50 | ~$45 | Burstable VM in management subnet for admin access |
| Container Registry (ACR) | Premium | ~$1.67 | ~$50 | Premium SKU required for private endpoint support |
| Key Vault | Standard tier | ~$0.03 | ~$1 | Charged per operation (secrets access, key operations) |
| Public IP (Jumpbox) | Standard SKU | ~$0.12 | ~$3.60 | Static public IP for RDP/WinRM access |
| Managed Identity | Free | $0.00 | $0.00 | No charge for User Assigned Managed Identity |
| Virtual Network | Free | $0.00 | $0.00 | No charge for VNet, subnets, or NSGs |
| Private Endpoint (ACR) | Per endpoint | ~$0.33 | ~$10 | Charged per hour for private endpoint |
| Private DNS Zone | Per zone | ~$0.02 | ~$0.50 | Minimal charge for DNS zone hosting |
| **Phase 2 Subtotal** | | **~$7.03** | **~$211** | |

### Phase 3-4: Additional Resources

| Resource | SKU / Tier | Daily Cost (USD) | Monthly Cost (USD) | Notes |
|----------|-----------|-----------------|-------------------|-------|
| Log Analytics Workspace | Pay-as-you-go | ~$0.50-$2.00 | ~$15-$60 | Depends on data ingestion volume (5-20 GB/day estimate) |
| Storage Account (Terraform state) | Standard LRS | ~$0.01 | ~$0.50 | Minimal storage for state files (<1 GB) |

### Cost Summary

| Phase | Monthly Cost (USD) | Notes |
|-------|-------------------|-------|
| Phase 1: Organization | $0 | GitHub Projects and public repositories are free |
| Phase 2: Infrastructure | ~$211 | AKS node + Jumpbox VM + ACR Premium are primary costs |
| Phase 3: CI/CD | ~$15-$60 | Log Analytics ingestion (shared with Phase 4) |
| Phase 4: Delivery | Included above | Uses same Log Analytics workspace as Phase 3 |
| **Total** | **~$226-$271/month** | Full pipeline with all phases active |

**Cost optimization tips:**
- Stop or deallocate AKS node pools when not actively testing (`az aks stop` — saves ~$101/month)
- Deallocate the jumpbox VM when not in use (`az vm deallocate` — saves ~$45/month)
- Use Azure Dev/Test pricing if available on your subscription
- Scale AKS to a single node during development (already configured as default)
- Set Log Analytics daily cap to control ingestion costs
- Destroy Phase 2-4 resources when not in use — Phase 1 resources persist for free
- ACR Premium is required for private endpoints; downgrade to Basic ($5/month) if private networking is not needed for testing

---

## Step-by-Step Deployment Guide

A complete guide from zero to a fully deployed DevSecOps pipeline.

### Prerequisites

Before starting, ensure you have the following tools installed and accounts configured:

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Git | 2.30+ | Version control operations |
| GitHub CLI (`gh`) | 2.21+ | Automates GitHub API operations (repos, projects, protection rules) |
| Terraform | 1.5+ | Infrastructure-as-code provisioning for Azure resources |
| Azure CLI (`az`) | 2.50+ | Azure authentication and resource management |
| PowerShell | 7.0+ | Script execution (cross-platform) |
| Ansible | 2.14+ | Post-deployment configuration management for jumpbox VM (Phase 2) |
| pywinrm | 0.4+ | Python WinRM library enabling Ansible to manage Windows hosts (Phase 2) |
| Checkov | 3.0+ | IaC security scanning — pre-deployment gate for Terraform code (Phase 2) |
| Python | 3.9+ | Required runtime for Ansible and Checkov |

**Accounts and subscriptions required:**
- GitHub account with a Personal Access Token (PAT) that includes `repo` and `project` scopes
- Azure subscription (Pay-As-You-Go or Visual Studio Enterprise recommended)
- Azure Service Principal with Contributor role for Terraform automation

### Environment Setup

1. **Authenticate GitHub CLI:**
   ```powershell
   gh auth login
   gh auth status  # Verify scopes include 'repo' and 'project'
   ```

2. **Authenticate Azure CLI:**
   ```powershell
   az login
   az account set --subscription "<your-subscription-id>"
   ```

3. **Verify Terraform installation:**
   ```powershell
   terraform --version  # Should be 1.5+
   ```

4. **Clone this repository:**
   ```powershell
   git clone https://github.com/<your-username>/azure-devsecops-pipeline.git
   cd "13 Enterprise DevSecOps Pipeline"
   ```

5. **Create Azure Storage Account for Terraform state** (one-time setup):
   ```powershell
   az group create --name rg-terraform-state --location eastus
   az storage account create --name tfstatedevsecops --resource-group rg-terraform-state --sku Standard_LRS
   az storage container create --name tfstate --account-name tfstatedevsecops
   ```

### Execution Order

Execute phases sequentially — each phase depends on outputs from the previous one.

#### Phase 1: Organization (~5 minutes)

```powershell
cd "phase 1/scripts"
./setup-phase1.ps1 -ProjectPrefix "devsecops"
```

**What this does:**
- Creates the GitHub Projects board with phase tracking fields
- Creates the Platform Repository with Terraform module structure
- Creates the Workload Repository with application scaffold
- Applies branch protection rules to both repositories
- Links both repositories to the project board

**Verify success:**
```powershell
./test-phase1.ps1 -ProjectPrefix "devsecops"
```

#### Phase 2: Infrastructure (~15-20 minutes)

**Additional prerequisites for Phase 2:**

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Ansible | 2.14+ | Post-deployment jumpbox configuration management |
| pywinrm | 0.4+ | Python WinRM library for Ansible Windows connectivity |
| Checkov | 3.0+ | IaC security scanning (pre-deployment gate) |

**Install Phase 2 prerequisites:**
```powershell
pip install ansible pywinrm checkov
ansible --version   # Verify 2.14+
checkov --version   # Verify 3.0+
```

**Set sensitive environment variables:**
```powershell
# Set the jumpbox admin password (never stored in .tfvars files)
$env:TF_VAR_vm_admin_password = "YourSecureP@ssw0rd123"

# Azure Service Principal credentials (if not using az login)
$env:ARM_CLIENT_ID = "<service-principal-app-id>"
$env:ARM_CLIENT_SECRET = "<service-principal-secret>"
$env:ARM_TENANT_ID = "<azure-tenant-id>"
$env:ARM_SUBSCRIPTION_ID = "<azure-subscription-id>"
```

**Run Checkov security scan (pre-deployment gate):**
```powershell
cd "phase 2"
checkov -d . --config-file .checkov.yaml
```

If Checkov reports high or critical findings, fix them before proceeding. Medium/low findings are logged as warnings.

**Deploy infrastructure:**
```powershell
cd "phase 2"
terraform init -backend-config="key=dev.terraform.tfstate"
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars" -auto-approve
```

**What this does:**
- Runs Checkov IaC security scanning against all Terraform files (in CI/CD pipeline)
- Provisions Azure Virtual Network with 3 subnets (AKS, app, management) and NSGs
- Creates Private Container Registry (ACR Premium) with private endpoint — no public access
- Deploys Key Vault with RBAC authorization, soft-delete, and purge protection
- Creates User Assigned Managed Identity with least-privilege role assignments (AcrPull, Key Vault Secrets User)
- Provisions AKS cluster with Azure CNI, RBAC enabled, local accounts disabled, and OMS agent
- Creates Windows Server 2022 jumpbox VM in management subnet with public IP
- Configures WinRM HTTPS listener via Custom Script Extension
- Executes Ansible playbook via `local-exec` provisioner to:
  - Install kubectl, Azure CLI, and helm on the jumpbox
  - Apply CIS Microsoft Windows Server 2022 Benchmark Level 1 hardening

**Verify Phase 2 deployment:**
```powershell
# Verify resource group
az group show --name rg-devsecops-dev --output table

# Verify VNet and subnets
az network vnet show --resource-group rg-devsecops-dev --name vnet-devsecops-dev --output table
az network vnet subnet list --resource-group rg-devsecops-dev --vnet-name vnet-devsecops-dev --output table

# Verify AKS cluster is running
az aks show --resource-group rg-devsecops-dev --name aks-devsecops-dev --query "provisioningState" --output tsv

# Verify ACR is private
az acr show --name acrdevsecopsdev --query "publicNetworkAccess" --output tsv

# Verify Key Vault
az keyvault show --name kv-devsecops-dev --query "{softDelete:properties.enableSoftDelete, purgeProtection:properties.enablePurgeProtection}" --output table

# Verify jumpbox VM is running
az vm show --resource-group rg-devsecops-dev --name vm-jumpbox-dev --show-details --query "powerState" --output tsv

# Verify Managed Identity
az identity show --resource-group rg-devsecops-dev --name id-aks-devsecops-dev --output table
```

#### Phase 3: CI/CD (~10 minutes)

```powershell
cd "phase 3"
terraform init -backend-config="key=dev-cicd.terraform.tfstate"
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars" -auto-approve
```

**What this does:**
- Configures GitHub Actions workflows with security scanning stages
- Integrates Trivy for container vulnerability scanning
- Sets up SonarQube for static code analysis
- Configures Snyk for dependency vulnerability monitoring

#### Phase 4: Delivery (~5 minutes)

```powershell
cd "phase 4"
terraform init -backend-config="key=dev-delivery.terraform.tfstate"
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars" -auto-approve
```

**What this does:**
- Creates Azure Monitor workspace and alert rules
- Configures Log Analytics for centralized logging
- Sets up dashboards for pipeline and application health
- Establishes alerting for security events and performance anomalies

### Teardown

To destroy all resources (reverse order to respect dependencies):

```powershell
# Phase 4
cd "phase 4"
terraform destroy -var-file="environments/dev.tfvars" -auto-approve

# Phase 3
cd "phase 3"
terraform destroy -var-file="environments/dev.tfvars" -auto-approve

# Phase 2 (ensure TF_VAR_vm_admin_password is set)
cd "phase 2"
$env:TF_VAR_vm_admin_password = "YourSecureP@ssw0rd123"
terraform destroy -var-file="environments/dev.tfvars" -auto-approve

# Phase 1 (GitHub resources)
cd "phase 1/scripts"
./teardown-phase1.ps1 -ProjectPrefix "devsecops"
```

**Phase 2 teardown notes:**
- Key Vault enters soft-deleted state (90-day retention) — purge manually if you need to recreate with the same name: `az keyvault purge --name kv-devsecops-dev`
- AKS cluster deletion takes ~5 minutes as Azure cleans up node pools and networking
- The `TF_VAR_vm_admin_password` environment variable must be set even for destroy operations
