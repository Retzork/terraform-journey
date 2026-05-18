# Terraform Azure Infrastructure Portfolio

## Overview
This repository contains a collection of Infrastructure-as-Code (IaC) projects built with Terraform on Microsoft Azure. The projects progress from foundational concepts to production-grade multi-region architectures, demonstrating a structured learning path through cloud networking, compute, data, observability, and security.

While developed as an educational sandbox, the templates are structured to provide a solid baseline for professional environments. **Important Note:** If adapting these modules for production use, thoroughly review and harden the security configurations. Some projects intentionally disable encryption or utilize permissive Network Security Groups (NSGs) for ease of testing.

## Azure Skills Demonstrated

| Domain | Services & Concepts |
|--------|-------------------|
| **Networking** | VNet, Subnets, NSG, VNet Peering (regional + global), UDR, Forced Tunneling, Azure CNI, Private Endpoints, Private Link Service, Private DNS Zones |
| **Security** | Azure Firewall (Standard + Basic), WAF, Azure Policy, Zero Trust, Managed Identity (User + System Assigned), RBAC, Entra ID integration |
| **Compute** | Virtual Machines (Windows + Linux), VMSS, AKS (private clusters), App Service, Docker, Custom Script Extensions, cloud-init |
| **Data** | SQL Server (IaaS), Azure SQL Database, Failover Groups, geo-replication, Private Endpoints for data |
| **Identity** | Active Directory DS, Domain Controllers, domain join automation, Entra ID, Workload Identity, OIDC |
| **Containers** | AKS, Azure CNI, HPA, Cluster Autoscaler, Helm, NGINX Ingress, Internal Load Balancers |
| **Observability** | Prometheus, Grafana, Azure Service Discovery, Windows Exporter, dashboard-as-code |
| **Global Traffic** | Azure Front Door Premium, Private Link origins, health probes, multi-region failover |
| **CI/CD** | GitHub Actions, Self-Hosted Runners, Managed Identity auth (IMDS), zip deploy |
| **IaC Patterns** | Multi-phase deployment, cross-state references, templatefile(), count/for_each, lifecycle rules, remote + local backends |

## Project Directory

| # | Project | Description |
|---|---------|-------------|
| 01 | [Demo or Test](./01%20Demo%20or%20Test) | Initial sandbox for testing providers and basic Azure authentication |
| 02 | [Three Tier Stack](./02%20Three%20Tier%20Stack) | Classic three-tier: IIS + ASP.NET + SQL Server across isolated subnets |
| 03 | [Three Tier Stack With API](./03%20Three%20Tier%20Stack%20With%20API%20in%20between) | Modernized three-tier: Nginx + Node.js Express + SQL Server |
| 04 | [Active Directory Environment](./04%20Active%20Directory%20Environment) | Automated AD DS Domain Controller + dynamic domain-joined members |
| 05 | [Active Directory With Windows SQL](./05%20Active%20Directory%20With%20Windows%20SQL) | AD environment extended with domain-joined SQL Server 2019 |
| 06 | [Whole Dynamics GP Environment](./06%20Whole%20Dynamics%20GP%20Environment) | Full Dynamics GP stack (deprecated) |
| 07 | [Dashboard to Existing Environment](./07%20Dashboard%20to%20Existing%20Environment) | Prometheus + Grafana observability stack with Azure Service Discovery |
| 08 | [Dummy](./08%20Dummy) | Target Windows VMs for monitoring stack testing |
| 09 | [Hub and Spoke](./09%20Hub%20and%20Spoke) | Enterprise hub-and-spoke with Azure Firewall + UDRs + centralized inspection |
| 10 | [Azure Kubernetes Service](./10%20Azure%20Kubernetes%20Service) | Production AKS: Azure CNI, Entra ID, HPA, Cluster Autoscaler, Helm Ingress |
| 11 | [Multi Region Zero Trust Architecture](./11%20Multi%20Region%20Zero%20Trust%20Architecture) | Multi-region hub-spoke with private AKS, Front Door, WAF, Private Link, SQL Failover |
| 12 | [Self-Hosted CI/CD Bridge](./12%20SelfHosted%20CICD%20Bridge) | GitHub Actions → Azure via Managed Identity, zero secrets, self-hosted runner |

## Highlighted Projects

Six projects are highlighted as the portfolio showcase. Each was selected because it demonstrates a distinct, non-overlapping skill that builds on the previous:

| # | Project | Why It's Highlighted |
|---|---------|---------------------|
| 04 | Active Directory | Demonstrates complex Windows infrastructure automation with boot-time dependencies — the DC must promote before members can join. Shows mastery of provisioning sequencing and custom script extensions. |
| 07 | Monitoring Stack | Unique angle that most Terraform portfolios lack. Combines IaC with observability (Prometheus + Grafana), Azure Managed Identity for service discovery, and a custom Python sanitizer for dashboard provisioning. |
| 09 | Hub and Spoke | Core enterprise networking pattern. Proves understanding of VNet peering, Azure Firewall as a centralized inspection point, User Defined Routes, and Layer 4/7 traffic filtering with default-deny posture. |
| 10 | AKS | Container orchestration with production patterns: Azure CNI networking, Entra ID RBAC, Workload Identity, two-tier autoscaling (HPA + Cluster Autoscaler), and Helm-based ingress deployment. |
| 11 | Zero Trust | The capstone. Multi-region, multi-phase orchestration combining everything: hub-spoke networking, private AKS clusters, Azure Firewall, Front Door Premium with Private Link origins, WAF, SQL Failover Groups, Azure Policy enforcement, and automated PE connection approval. |
| 12 | CI/CD Bridge | Solves a real enterprise constraint: deploying to Azure without Entra ID permissions. Self-hosted GitHub Actions runner with Managed Identity authentication (IMDS). Zero secrets stored anywhere. |

The remaining projects (01–03, 05, 06, 08) are either superseded by later work, too generic (every tutorial covers three-tier), or serve as utility/support for the highlighted ones.

## Deployment Time Estimates

Realistic durations based on actual deployment runs. Azure Firewall and AKS cluster provisioning are the primary bottlenecks across all projects.

| Project | Apply | Destroy | Bottleneck |
|---------|-------|---------|------------|
| 04 AD Environment | ~12 min | ~8 min | Custom script extensions (AD promotion + domain join polling) |
| 07 Monitoring Stack | ~8 min | ~5 min | Cloud-init (Docker image pull + container startup) |
| 09 Hub and Spoke | ~20 min | ~15 min | Azure Firewall Standard provisioning / deallocation |
| 10 AKS | ~12 min | ~5 min | AKS cluster creation |
| 11 Zero Trust | ~45 min | ~60 min | 2× Firewalls + 2× AKS clusters + Front Door + DNS zone links |
| 12 CI/CD Bridge | ~5 min | ~2 min | VM creation + Storage Account provisioning |

**Project 11 phase breakdown:**

| | phase1_networking | phase2_data | phase3_compute | phase4_final |
|---|---|---|---|---|
| Apply | ~18 min | ~5 min | ~12 min | ~10 min |
| Destroy | ~25 min | ~8 min | ~15 min | ~12 min |

## Cost Estimation

All prices are approximate USD pay-as-you-go rates for the Southeast Asia region. The recommended approach is deploy → validate → destroy to minimize cost.

### Per-Project Breakdown

**Project 04 — Active Directory Environment (~$12/day with 4 members)**

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

**Project 09 — Hub and Spoke (~$31/day if left running)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| Azure Firewall | Standard | 1 | $1.25 |
| Spoke VMs (Linux) | Standard_B1s | 2 | $0.021 |
| Public IP | Standard Static | 1 | $0.005 |

**Project 10 — AKS (~$4/day if left running)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| AKS Control Plane | Free tier | 1 | Free |
| Node Pool VM | Standard_DS2_v2 | 1 | $0.096 |
| Load Balancer | Standard | 1 | $0.025 |
| Public IP | Standard Static | 1 | $0.005 |

**Project 11 — Multi Region Zero Trust (~$29/day if left running)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| Azure Firewall | Basic | 2 | $0.875 |
| AKS Clusters (nodes) | Free tier + B2s_v2 | 2 | $0.166 |
| Jumpbox VM | Standard_B2s_v2 | 1 | $0.083 |
| Azure Front Door | Premium | 1 | $0.452 |
| Azure SQL Database | Basic (5 DTU) | 2 | $0.014 |
| Private Endpoints | — | 2 | $0.010 |
| Public IPs | Standard Static | 6 | $0.030 |

**Project 12 — Self-Hosted CI/CD Bridge (~$1/day if left running)**

| Resource | SKU | Qty | $/hour |
|----------|-----|-----|--------|
| Runner VM (Linux) | Standard_B2s_v2 | 1 | $0.042 |
| App Service Plan | B1 Linux | 1 | $0.018 |
| Storage Account | Standard LRS | 1 | ~$0.001 |
| VNet/NSG/Identity | — | — | Free |

### Summary

| Project | Daily Cost | Monthly Cost | Biggest Cost Driver |
|---------|-----------|--------------|---------------------|
| 04 AD Environment | ~$12/day | ~$379/mo | VMs (1 DC + 4 members, member count is configurable) |
| 07 Monitoring Stack | ~$1/day | ~$34/mo | Hub VM only (target VMs are existing infrastructure) |
| 09 Hub and Spoke | ~$31/day | ~$935/mo | Azure Firewall Standard (97% of cost) |
| 10 AKS | ~$4/day | ~$111/mo | Node VM (DS2_v2) |
| 11 Zero Trust | ~$29/day | ~$1,212/mo | Firewalls (53%) + Front Door (27%) |
| 12 CI/CD Bridge | ~$1/day | ~$28/mo | Runner VM (58%) + App Service (42%) |

### Cost Optimization Tips

1. **Deploy → Validate → Destroy** — Keep resources up only during testing. All 6 highlighted projects can be demoed for under $5 total.
2. **Use B-series VMs** — Project 04 uses D2s_v3 ($0.096/hr). Switching to B2s ($0.042/hr) saves 56%.
3. **AKS Free Tier** — Projects 10 and 11 use Free tier. No control plane charge.
4. **Front Door Standard vs Premium** — Standard is $35/mo vs Premium at $330/mo. Project 11 requires Premium for Private Link.
5. **Azure Firewall dominates cost** — For projects 09 and 11, the firewall is the single largest expense. Deploy and destroy quickly.

## Usage
Each folder contains its own `README.md` with specific variables, setup instructions, and deployment details. Standard workflow:
```
terraform init
terraform plan
terraform apply
```

For Project 11, use the orchestration script:
```powershell
.\manage.ps1 -Action apply    # Deploy all 4 phases in order
.\manage.ps1 -Action destroy  # Tear down in reverse order
```

---

*All prices are approximate USD pay-as-you-go rates for Southeast Asia. Last verified: May 2026.*
