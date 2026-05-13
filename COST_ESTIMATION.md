# Cost Estimation Breakdown — Portfolio Projects

All prices are approximate USD pay-as-you-go rates (Southeast Asia / East Asia regions). Actual costs vary by region, usage, and any free tier credits applied.

---

## Project 04 — Active Directory Environment

| Resource | SKU | Qty | $/hour | $/day | $/month |
|----------|-----|-----|--------|-------|---------|
| Domain Controller VM | Standard_D2s_v3 (2 vCPU, 8 GB) | 1 | $0.096 | $2.30 | $70.08 |
| Member VMs | Standard_D2s_v3 | 4 | $0.384 | $9.22 | $280.32 |
| Public IP (Standard) | Static | 1 | $0.005 | $0.12 | $3.65 |
| Managed Disks (OS) | Standard SSD 128 GB | 5 | — | $0.83 | $25.20 |
| VNet / NSG | — | — | Free | Free | Free |

| **Total** | | | | **~$12.47/day** | **~$379/month** |

> Tip: Use Standard_B2s ($0.042/hr) instead of D2s_v3 for demos. Drops to ~$165/month.

---

## Project 07 — Dashboard to Existing Environment

| Resource | SKU | Qty | $/hour | $/day | $/month |
|----------|-----|-----|--------|-------|---------|
| Hub VM (Linux) | Standard_B2s (2 vCPU, 4 GB) | 1 | $0.042 | $1.01 | $30.66 |
| Target Windows VMs | Standard_B2s | 2 | $0.084 | $2.02 | $61.32 |
| Public IP (Hub) | Static | 1 | $0.005 | $0.12 | $3.65 |
| Managed Disks (OS) | Standard SSD 128 GB | 3 | — | $0.50 | $15.12 |
| VNet / NSG | — | — | Free | Free | Free |
| **Total** | — | — | — | **~$3.65/day** | **~$111/month** |

> Note: Target VMs may already exist (the project attaches to existing infra). If so, only the Hub VM cost applies (~$34/month).

---

## Project 09 — Hub and Spoke

| Resource | SKU | Qty | $/hour | $/day | $/month |
|----------|-----|-----|--------|-------|---------|
| Azure Firewall | Standard SKU | 1 | $1.25 | $30.00 | $912.50 |
| Spoke VMs (Linux) | Standard_B1s (1 vCPU, 1 GB) | 2 | $0.021 | $0.50 | $15.33 |
| Public IPs | Standard (Firewall) | 1 | $0.005 | $0.12 | $3.65 |
| Managed Disks | Standard SSD 30 GB | 2 | — | $0.10 | $3.02 |
| VNets / Peering | 3 VNets, 4 peering links | — | Free | Free | Free |
| Route Tables | — | — | Free | Free | Free |
| **Total** | | | | **~$30.72/day** | **~$935/month** |

> The Azure Firewall dominates cost (97%). For demo purposes, deploy → validate → destroy within 1-2 hours (~$1.30 total).

---

## Project 10 — Azure Kubernetes Service

| Resource | SKU | Qty | $/hour | $/day | $/month |
|----------|-----|-----|--------|-------|---------|
| AKS Control Plane | Free tier | 1 | Free | Free | Free |
| Node Pool VM | Standard_DS2_v2 (2 vCPU, 7 GB) | 1-5 | $0.096 | $2.30 | $70.08 |
| Load Balancer | Standard (auto-created) | 1 | $0.025 | $0.60 | $18.25 |
| Public IP (LB) | Standard | 1 | $0.005 | $0.12 | $3.65 |
| Managed Disk (OS) | Premium SSD 128 GB | 1 | — | $0.63 | $19.17 |
| VNet | — | 1 | Free | Free | Free |
| **Total (1 node)** | | | | **~$3.65/day** | **~$111/month** |
| **Total (5 nodes, autoscaled)** | | | | **~$12.85/day** | **~$391/month** |

> AKS Free tier = no control plane charge. You only pay for node VMs + storage + networking.

---

## Project 11 — Multi Region Zero Trust Architecture

| Resource | SKU | Qty | $/hour | $/day | $/month |
|----------|-----|-----|--------|-------|---------|
| Azure Firewall | Basic SKU | 2 | $0.875 | $21.00 | $638.75 |
| AKS Clusters | Free tier (nodes: B2s_v2) | 2 | $0.166 | $3.98 | $121.18 |
| Jumpbox VM | Standard_B2s_v2 (Linux) | 1 | $0.083 | $1.99 | $60.59 |
| Azure Front Door | Premium | 1 | — | — | $330.00 |
| Azure SQL Database | Basic (5 DTU) | 2 | — | $0.33 | $9.99 |
| SQL Failover Group | — | 1 | Free | Free | Free |
| Private Endpoints | — | 2 | $0.010/hr each | $0.48 | $14.60 |
| Private Link Services | — | 2 | Free | Free | Free |
| Public IPs | Standard | 6 | $0.030 | $0.72 | $21.90 |
| Managed Disks | Standard SSD 128 GB | 3 | — | $0.50 | $15.12 |
| VNets / Peering | 4 VNets, 6 peering links | — | Free | Free | Free |
| WAF Policy | Included in FD Premium | — | — | — | Included |
| Azure Policy | — | — | Free | Free | Free |
| **Total** | | | | **~$29.00/day** | **~$1,212/month** |

### Cost Breakdown by Category

```
Firewalls (2x Basic)     $639/mo  ██████████████████░░  53%
Front Door Premium       $330/mo  █████████░░░░░░░░░░░  27%
AKS Nodes (2x B2s_v2)    $121/mo  ███░░░░░░░░░░░░░░░░░  10%
Jumpbox VM                $61/mo  ██░░░░░░░░░░░░░░░░░░   5%
Other (SQL, PE, IPs)      $61/mo  ██░░░░░░░░░░░░░░░░░░   5%
```

---

## Summary Comparison

| Project | Daily Cost | Monthly Cost | Biggest Cost Driver |
|---------|-----------|--------------|---------------------|
| 04 AD Environment | ~$12/day | ~$379/mo | VMs (5x D2s_v3) |
| 07 Monitoring Stack | ~$4/day | ~$111/mo | VMs (3x B2s) |
| 09 Hub and Spoke | ~$31/day | ~$935/mo | Azure Firewall Standard |
| 10 AKS | ~$4/day | ~$111/mo | Node VM (DS2_v2) |
| 11 Zero Trust | ~$29/day | ~$1,212/mo | Firewalls + Front Door |

---

## Deployment Time Estimates

### Apply

| Project | Time | Bottleneck |
|---------|------|------------|
| 04 AD Environment | ~12 min | Custom script extensions (AD promotion + domain join polling) |
| 07 Monitoring Stack | ~8 min | Cloud-init (Docker pull + container start) |
| 09 Hub and Spoke | ~20 min | Azure Firewall Standard provisioning (~15 min) |
| 10 AKS | ~12 min | AKS cluster creation (~10 min) |
| 11 Zero Trust | ~45 min | 2× Firewall Basic (~15 min) + 2× AKS (~10 min) + Front Door |

**Project 11 apply breakdown:**
| Phase | Time |
|-------|------|
| phase1_networking | ~18 min |
| phase2_data | ~5 min |
| phase3_compute | ~12 min |
| phase4_final | ~10 min |

---

### Destroy

| Project | Time | Bottleneck |
|---------|------|------------|
| 04 AD Environment | ~8 min | VM deletion (parallel) |
| 07 Monitoring Stack | ~5 min | VM + extension cleanup |
| 09 Hub and Spoke | ~15 min | Azure Firewall deallocation (~10 min) |
| 10 AKS | ~5 min | AKS cluster deletion |
| 11 Zero Trust | ~60 min | Firewalls + DNS zone links + AKS + Front Door PE cleanup |

**Project 11 destroy breakdown:**
| Phase | Time |
|-------|------|
| phase4_final | ~12 min |
| phase3_compute | ~15 min |
| phase2_data | ~8 min |
| phase1_networking | ~25 min |

---

## Cost Optimization Tips

1. **Deploy → Test → Destroy** — For portfolio demos, keep resources up only during testing. A 2-hour session for Project 11 costs ~$2.40 instead of $29/day.
2. **Downgrade Firewall SKU** — Project 09 uses Standard ($1.25/hr). If you only need L3/L4 filtering, Basic ($0.44/hr) cuts cost by 65%.
3. **Use B-series VMs** — Project 04 uses D2s_v3 ($0.096/hr). Switching to B2s ($0.042/hr) saves 56% on compute.
4. **AKS Free Tier** — Both projects 10 and 11 use Free tier (no control plane charge). Only upgrade to Standard ($0.10/hr) for production SLA.
5. **Front Door Standard vs Premium** — If you don't need Private Link origins or Bot Manager, Standard ($35/mo) is 90% cheaper than Premium ($330/mo). Project 11 requires Premium for Private Link.

---

*Prices sourced from Azure pricing pages and third-party calculators. Estimates based on Southeast Asia region, pay-as-you-go, Linux VMs where applicable. Last verified: May 2026.*
