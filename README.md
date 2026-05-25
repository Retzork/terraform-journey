# Terraform Azure Infrastructure Portfolio

## Overview

A progressive collection of Infrastructure-as-Code projects built with Terraform on Microsoft Azure — from foundational sandbox experiments to production-grade multi-region architectures and enterprise DevSecOps pipelines.

The projects demonstrate a structured learning path through cloud networking, compute, data, observability, security, CI/CD automation, and DevSecOps practices. While developed as an educational sandbox, the templates are structured to provide a solid baseline for professional environments.

> **Security Note:** If adapting these modules for production use, thoroughly review and harden the security configurations. Some projects intentionally disable encryption or utilize permissive Network Security Groups (NSGs) for ease of testing.

---

## Global Prerequisites

| Requirement | Details |
|-------------|---------|
| Terraform | >= 1.0 with AzureRM provider ~> 3.0 |
| Azure CLI | Installed and authenticated (`az login`) |
| Azure Subscription | Sufficient permissions to deploy networking, compute, and Kubernetes resources |
| Default Region | `southeastasia` (configurable per project) |

---

## Project Directory

| # | Project | Description | Complexity |
|---|---------|-------------|:----------:|
| 01 | [Demo or Test](./01%20Demo%20or%20Test) | Initial sandbox for testing providers and basic Azure authentication | ⭐ |
| 02 | [Three Tier Stack](./02%20Three%20Tier%20Stack) | Classic three-tier: IIS + ASP.NET + SQL Server across isolated subnets | ⭐⭐ |
| 03 | [Three Tier Stack With API](./03%20Three%20Tier%20Stack%20With%20API%20in%20between) | Modernized three-tier: Nginx + Node.js Express + SQL Server | ⭐⭐ |
| 04 | [Active Directory Environment](./04%20Active%20Directory%20Environment) | Automated AD DS Domain Controller + dynamic domain-joined members | ⭐⭐⭐ |
| 05 | [Active Directory With Windows SQL](./05%20Active%20Directory%20With%20Windows%20SQL) | AD environment extended with domain-joined SQL Server 2019 | ⭐⭐⭐ |
| 06 | [Whole Dynamics GP Environment](./06%20Whole%20Dynamics%20GP%20Environment) | Full Dynamics GP stack (deprecated) | ⭐⭐⭐ |
| 07 | [Dashboard to Existing Environment](./07%20Dashboard%20to%20Existing%20Environment) | Prometheus + Grafana observability stack with Azure Service Discovery | ⭐⭐⭐ |
| 08 | [Dummy](./08%20Dummy) | Target Windows VMs for monitoring stack testing | ⭐ |
| 09 | [Hub and Spoke](./09%20Hub%20and%20Spoke) | Enterprise hub-and-spoke with Azure Firewall + UDRs + centralized inspection | ⭐⭐⭐⭐ |
| 10 | [Azure Kubernetes Service](./10%20Azure%20Kubernetes%20Service) | Production AKS: Azure CNI, Entra ID, HPA, Cluster Autoscaler, Helm Ingress | ⭐⭐⭐⭐ |
| 11 | [Multi Region Zero Trust Architecture](./11%20Multi%20Region%20Zero%20Trust%20Architecture) | Multi-region hub-spoke with private AKS, Front Door, WAF, Private Link, SQL Failover | ⭐⭐⭐⭐⭐ |
| 12 | [Self-Hosted CI/CD Bridge](./12%20SelfHosted%20CICD%20Bridge) | GitHub Actions self-hosted runner with Managed Identity — zero-secret Azure deployments | ⭐⭐⭐ |
| 13 | [Enterprise DevSecOps Pipeline](./13%20Enterprise%20DevSecOps%20Pipeline) | Four-phase DevSecOps pipeline: Organization → Infrastructure → CI/CD → Delivery (16 tools) | ⭐⭐⭐⭐⭐ |

---

## Learning Path

The projects are ordered by complexity. Here's a suggested progression:

```
Foundations          Networking & Compute       Enterprise Patterns         DevSecOps
──────────          ────────────────────       ────────────────────        ─────────
01 Demo/Test   ──►  02 Three Tier         ──►  09 Hub and Spoke      ──►  12 CI/CD Bridge
                    03 Three Tier + API        10 AKS                     13 DevSecOps Pipeline
                    04 Active Directory        11 Zero Trust
                    05 AD + SQL
                    07 Monitoring Stack
```

---

## Highlighted Projects

Seven projects are highlighted as the portfolio showcase. Each demonstrates a distinct, non-overlapping skill:

| # | Project | Why It's Highlighted |
|---|---------|---------------------|
| 04 | Active Directory | Complex Windows infrastructure automation with boot-time dependencies — the DC must promote before members can join. Demonstrates provisioning sequencing and custom script extensions. |
| 07 | Monitoring Stack | Unique angle most Terraform portfolios lack. Combines IaC with observability (Prometheus + Grafana), Azure Managed Identity for service discovery, and a custom Python sanitizer for dashboard provisioning. |
| 09 | Hub and Spoke | Core enterprise networking pattern. VNet peering, Azure Firewall as centralized inspection, User Defined Routes, and Layer 4/7 traffic filtering with default-deny posture. |
| 10 | AKS | Container orchestration with production patterns: Azure CNI networking, Entra ID RBAC, Workload Identity, two-tier autoscaling (HPA + Cluster Autoscaler), and Helm-based ingress. |
| 11 | Zero Trust | Multi-region, multi-phase orchestration combining hub-spoke networking, private AKS clusters, Azure Firewall, Front Door Premium with Private Link origins, WAF, SQL Failover Groups, Azure Policy enforcement, and automated PE connection approval. |
| 12 | CI/CD Bridge | Solves a real enterprise constraint: deploying to Azure without Service Principal or OIDC. Zero-secret architecture using Self-Hosted Runner + Managed Identity + IMDS. Demonstrates least-privilege and defense-in-depth. |
| 13 | DevSecOps Pipeline | End-to-end enterprise pipeline integrating 16 tools across 4 phases. Covers project management, IaC security scanning (Checkov), container scanning (Trivy), SAST (SonarQube), SCA (Snyk), CIS hardening (Ansible), and observability. |

The remaining projects (01–03, 05, 06, 08) are either superseded by later work, too generic (every tutorial covers three-tier), or serve as utility/support for the highlighted ones.

---

## Deployment Time Estimates

Realistic durations based on actual deployment runs. Azure Firewall and AKS cluster provisioning are the primary bottlenecks.

| Project | Apply | Destroy | Bottleneck |
|---------|-------|---------|------------|
| 04 AD Environment | ~12 min | ~8 min | Custom script extensions (AD promotion + domain join polling) |
| 07 Monitoring Stack | ~8 min | ~5 min | Cloud-init (Docker image pull + container startup) |
| 09 Hub and Spoke | ~20 min | ~15 min | Azure Firewall Standard provisioning / deallocation |
| 10 AKS | ~12 min | ~5 min | AKS cluster creation |
| 11 Zero Trust | ~45 min | ~60 min | 2× Firewalls + 2× AKS clusters + Front Door + DNS zone links |
| 12 CI/CD Bridge | ~8 min | ~5 min | VM provisioning + GitHub runner registration via custom_data |
| 13 DevSecOps Pipeline | ~35-40 min | ~20-25 min | AKS cluster (~10 min) + Ansible jumpbox provisioning (~5 min) |

### Project 11 — Phase Breakdown

| | phase1_networking | phase2_data | phase3_compute | phase4_final |
|---|---|---|---|---|
| Apply | ~18 min | ~5 min | ~12 min | ~10 min |
| Destroy | ~25 min | ~8 min | ~15 min | ~12 min |

### Project 13 — Phase Breakdown

| | Phase 1: Organization | Phase 2: Infrastructure | Phase 3: CI/CD | Phase 4: Delivery |
|---|---|---|---|---|
| Apply | ~5 min | ~15-20 min | ~10 min | ~5 min |
| Destroy | ~2 min | ~10-15 min | ~5 min | ~3 min |

---

## Cost Estimation

All prices are approximate USD pay-as-you-go rates for the Southeast Asia region. The recommended approach is **deploy → validate → destroy** to minimize cost.

### Per-Project Breakdown

**Project 04 — Active Directory Environment (~$12/day)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| Domain Controller VM | Standard_D2s_v3 | 1 | $0.096 |
| Member VMs | Standard_D2s_v3 | var.domain_member_count (default: 4) | $0.096 each |
| Public IP | Standard Static | 1 | $0.005 |
| Managed Disks | Standard SSD 128 GB | 1 + member count | ~$0.007 each |

**Project 07 — Monitoring Stack (~$1/day)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| Hub VM (Linux) | Standard_B2s | 1 | $0.042 |
| Public IP | Standard Static | 1 | $0.005 |
| Managed Disk | Standard SSD 128 GB | 1 | ~$0.007 |

> Target Windows VMs are not counted — the project attaches to existing infrastructure via Custom Script Extensions.

**Project 09 — Hub and Spoke (~$31/day)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| Azure Firewall | Standard | 1 | $1.25 |
| Spoke VMs (Linux) | Standard_B1s | 2 | $0.021 |
| Public IP | Standard Static | 1 | $0.005 |

**Project 10 — AKS (~$4/day)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| AKS Control Plane | Free tier | 1 | Free |
| Node Pool VM | Standard_DS2_v2 | 1 | $0.096 |
| Load Balancer | Standard | 1 | $0.025 |
| Public IP | Standard Static | 1 | $0.005 |

**Project 11 — Multi Region Zero Trust (~$29/day)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| Azure Firewall | Basic | 2 | $0.875 |
| AKS Clusters (nodes) | Free tier + B2s_v2 | 2 | $0.166 |
| Jumpbox VM | Standard_B2s_v2 | 1 | $0.083 |
| Azure Front Door | Premium | 1 | $0.452 |
| Azure SQL Database | Basic (5 DTU) | 2 | $0.014 |
| Private Endpoints | — | 2 | $0.010 |
| Public IPs | Standard Static | 6 | $0.030 |

**Project 12 — Self-Hosted CI/CD Bridge (~$1/day)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| Runner VM (Linux) | Standard_B2s_v2 | 1 | $0.042 |
| App Service | B1 | 1 | $0.018 |
| Storage Account | Standard LRS | 1 | ~$0.001 |
| VNet/NSG/Identity | — | — | Free |

**Project 13 — Enterprise DevSecOps Pipeline (~$7/day)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| AKS Cluster (node) | Standard_DS2_v2 | 1 | $0.140 |
| Jumpbox VM | Standard_B2s_v2 | 1 | $0.063 |
| Container Registry | Premium | 1 | $0.070 |
| Key Vault | Standard | 1 | ~$0.001 |
| Private Endpoint (ACR) | — | 1 | $0.014 |
| Log Analytics | Pay-as-you-go | 1 | ~$0.021 |
| Public IP (Jumpbox) | Standard Static | 1 | $0.005 |

### Summary

| Project | Daily Cost | Monthly Cost | Biggest Cost Driver |
|---------|-----------|--------------|---------------------|
| 04 AD Environment | ~$12/day | ~$379/mo | VMs (1 DC + 4 members) |
| 07 Monitoring Stack | ~$1/day | ~$34/mo | Hub VM only |
| 09 Hub and Spoke | ~$31/day | ~$935/mo | Azure Firewall Standard (97% of cost) |
| 10 AKS | ~$4/day | ~$111/mo | Node VM (DS2_v2) |
| 11 Zero Trust | ~$29/day | ~$1,212/mo | Firewalls (53%) + Front Door (27%) |
| 12 CI/CD Bridge | ~$1/day | ~$28/mo | VM + App Service |
| 13 DevSecOps Pipeline | ~$7/day | ~$211-271/mo | AKS node + Jumpbox + ACR Premium |

### Cost Optimization Tips

1. **Deploy → Validate → Destroy** — Keep resources up only during testing. All projects can be demoed for under $5 total.
2. **Use B-series VMs** — Project 04 uses D2s_v3 ($0.096/hr). Switching to B2s ($0.042/hr) saves 56%.
3. **AKS Free Tier** — Projects 10, 11, and 13 use Free tier. No control plane charge.
4. **Front Door Standard vs Premium** — Standard is $35/mo vs Premium at $330/mo. Project 11 requires Premium for Private Link.
5. **Azure Firewall dominates cost** — For projects 09 and 11, the firewall is the single largest expense. Deploy and destroy quickly.
6. **Stop AKS when idle** — `az aks stop` saves node VM costs for projects 10, 11, and 13.
7. **Deallocate VMs** — `az vm deallocate` for jumpbox/runner VMs when not actively testing.

---

## Usage

Each folder contains its own `README.md` with specific variables, setup instructions, and deployment details.

### Standard Workflow

```bash
terraform init
terraform plan
terraform apply
```

### Project-Specific Commands

**Project 11 — Multi Region Zero Trust** (multi-phase orchestration):
```powershell
.\manage.ps1 -Action apply    # Deploy all 4 phases in order
.\manage.ps1 -Action destroy  # Tear down in reverse order
```

**Project 12 — Self-Hosted CI/CD Bridge:**
```bash
terraform init
terraform apply -var-file="terraform.tfvars"
# Runner auto-registers via custom_data
# Push to cicd-testing repo → auto-deploys to App Service
terraform destroy -var-file="terraform.tfvars"
```

**Project 13 — Enterprise DevSecOps Pipeline** (sequential phases):
```powershell
# Phase 1: Organization (GitHub resources)
cd "phase 1/scripts"
./setup-phase1.ps1 -ProjectPrefix "devsecops"

# Phase 2: Infrastructure (Azure resources)
cd "phase 2"
checkov -d . --config-file .checkov.yaml          # Security gate
terraform init -backend-config="key=dev.terraform.tfstate"
terraform apply -var-file="environments/dev.tfvars"

# Phase 3: CI/CD
cd "phase 3"
terraform init -backend-config="key=dev-cicd.terraform.tfstate"
terraform apply -var-file="environments/dev.tfvars"

# Phase 4: Delivery
cd "phase 4"
terraform init -backend-config="key=dev-delivery.terraform.tfstate"
terraform apply -var-file="environments/dev.tfvars"
```

---

## Skills Demonstrated

A summary of the technical skills and Azure services covered across all projects:

| Category | Skills & Services |
|----------|-------------------|
| **Networking** | VNet, Subnets, NSGs, VNet Peering, Azure Firewall, UDRs, Private Endpoints, Private DNS Zones, Front Door, WAF |
| **Compute** | Virtual Machines (Windows/Linux), VMSS, AKS, App Service, Custom Script Extensions, Cloud-Init |
| **Identity & Security** | Entra ID, Managed Identity, RBAC, Azure Policy, Key Vault, Zero Trust, CIS Hardening |
| **Data** | Azure SQL, SQL Failover Groups, Storage Accounts |
| **Containers** | AKS, Azure CNI, HPA, Cluster Autoscaler, Helm, ACR, Private Container Registry |
| **Observability** | Prometheus, Grafana, Azure Monitor, Log Analytics, Custom Dashboards |
| **CI/CD** | GitHub Actions, Self-Hosted Runners, Managed Identity Auth, Zip Deploy |
| **DevSecOps** | Checkov (IaC scanning), Trivy (container scanning), SonarQube (SAST), Snyk (SCA), Ansible (CIS hardening) |
| **Configuration Mgmt** | Ansible, WinRM, PowerShell DSC, Custom Data scripts |
| **Architecture Patterns** | Three-tier, Hub-and-spoke, Zero Trust, Multi-region, Multi-phase orchestration, Two-layer separation |

---

## Repository Structure

```
learning/
├── 01 Demo or Test/                          # Provider testing sandbox
├── 02 Three Tier Stack/                      # IIS + ASP.NET + SQL
├── 03 Three Tier Stack With API in between/  # Nginx + Node.js + SQL
├── 04 Active Directory Environment/          # AD DS automation
├── 05 Active Directory With Windows SQL/     # AD + SQL Server 2019
├── 06 Whole Dynamics GP Environment/         # Dynamics GP (deprecated)
├── 07 Dashboard to Existing Environment/     # Prometheus + Grafana
├── 08 Dummy/                                 # Target VMs for monitoring
├── 09 Hub and Spoke/                         # Enterprise networking
├── 10 Azure Kubernetes Service/              # Production AKS
├── 11 Multi Region Zero Trust Architecture/  # Multi-region capstone
├── 12 SelfHosted CICD Bridge/               # Zero-secret CI/CD
├── 13 Enterprise DevSecOps Pipeline/         # Full DevSecOps pipeline
│   ├── phase 1/                              #   Organization (GitHub)
│   └── phase 2/                              #   Infrastructure (Azure)
└── README.md                                 # This file
```

---

*All prices are approximate USD pay-as-you-go rates for Southeast Asia. Last verified: May 2025.*
