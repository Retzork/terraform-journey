# 12 — Self-Hosted CI/CD Bridge

Deploy to Azure from GitHub Actions **without a Service Principal or OIDC** — using a Self-Hosted Runner VM with a User-Assigned Managed Identity.

---

## DevSecOps Overview

This project implements a **secure CI/CD bridge** that solves a common enterprise constraint: deploying to Azure when you lack Entra ID tenant permissions. Every design decision prioritizes the principle of **least privilege** and **zero-trust**.

### Tools & Their Roles

| Tool | Role | Why |
|------|------|-----|
| **Terraform** | Infrastructure as Code | Declarative, auditable, version-controlled infra. Destroy/recreate in minutes. |
| **GitHub Actions** | CI/CD Orchestrator | Defines the pipeline as code. Triggers on push, auditable run history. |
| **Self-Hosted Runner** | Execution Environment | Runs inside your Azure network. No code leaves your subscription. |
| **Managed Identity (UAMI)** | Authentication | Zero secrets. Token only obtainable from within the VM. Cannot be leaked. |
| **IMDS** | Token Provider | Link-local endpoint (169.254.169.254). Unreachable from internet. |
| **NSG** | Network Security | Denies all inbound internet traffic. Runner only needs outbound. |
| **Azure App Service** | Application Hosting | PaaS target. Managed patching, TLS, scaling. |
| **Azure CLI** | Deployment Tool | Executes `az webapp deploy` using the IMDS-issued token. |

### Security Boundaries

```
┌──────────────────────────────────────────────────────────────────────┐
│                        TRUST BOUNDARY                                │
│                                                                      │
│  ┌───────────────┐         ┌────────────────────────────────────┐    │
│  │ GitHub (SaaS) │         │ Azure Subscription (Your Tenant)   │    │
│  │               │         │                                    │    │
│  │ • Stores code │  poll   │  VM (Self-Hosted Runner)           │    │
│  │ • Queues jobs │◄────────│  • No public IP                    │    │
│  │ • Shows logs  │         │  • NSG: deny inbound internet      │    │
│  │               │         │  • UAMI attached (Contributor)     │    │
│  │ Secrets: NONE │         │  • Secrets: NONE                   │    │
│  └───────────────┘         │         │                          │    │
│                            │         │ az login --identity      │    │
│                            │         ▼                          │    │
│                            │  IMDS (169.254.169.254)            │    │
│                            │  • Link-local only                 │    │
│                            │  • Returns short-lived token (24h) │    │
│                            │         │                          │    │
│                            │         ▼                          │    │
│                            │  Azure Resource Manager            │    │
│                            │  • App Service deployment          │    │
│                            └────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

### DevSecOps Principles Applied

| Principle | Implementation |
|-----------|---------------|
| **Zero secrets** | No credentials stored in GitHub, pipelines, or environment variables |
| **Least privilege** | UAMI has Contributor (not Owner). Cannot modify IAM or Entra ID. |
| **Defense in depth** | NSG + no public IP + IMDS link-local + short-lived tokens |
| **Infrastructure as Code** | All infra is Terraform. Auditable, reviewable, destroyable. |
| **Immutable deployments** | Zip deploy replaces app atomically. No SSH, no manual changes. |
| **Separation of concerns** | Platform (Layer 1) vs Application (Layer 2) are independent |
| **Blast radius containment** | PAT scoped to single repo. UAMI scoped to subscription. |
| **Auditability** | GitHub Actions logs every deployment. Azure Activity Log tracks API calls. |

### Threat Model

| Threat | Mitigation |
|--------|-----------|
| PAT leaked | Fine-grained, scoped to single repo. Revoke immediately. Cannot access Azure. |
| Malicious PR runs on runner | Disable fork PR workflows. Only `main` branch triggers. |
| Attacker on the internet | NSG denies all inbound. No public IP. No SSH. |
| Token stolen from VM | Token is short-lived (24h). Only valid for this subscription. |
| State file tampered | Local state on developer machine. Not exposed to network. |
| Supply chain attack (actions) | Pin action versions (`actions/checkout@v4`). Review before use. |

### What This Architecture Eliminates

| Traditional Risk | Status |
|-----------------|--------|
| Service Principal secret in GitHub Secrets | **Eliminated** — no SP exists |
| Secret rotation failures breaking pipelines | **Eliminated** — nothing to rotate |
| Overprivileged service accounts | **Mitigated** — Contributor, not Owner |
| Secrets in pipeline logs | **Eliminated** — no secrets to accidentally print |
| Credential sprawl across environments | **Eliminated** — identity is bound to VM lifecycle |

---

## Architecture Layers

```
Layer 1: PLATFORM (this project — local state, managed by you)
├── Resource Group, VNet, Subnet, NSG
├── User-Assigned Managed Identity (Contributor @ subscription)
├── Linux VM (GitHub Runner + Docker + AZ CLI)
├── App Service Plan + Web App
└── Storage Account (separate RG, optional)

Layer 2: APPLICATION (github.com/Retzork/cicd-testing — managed by pipeline)
├── app/ (index.html, server.js)
└── .github/workflows/deploy.yml
    → az login --identity
    → az webapp deploy
```

**Why two layers?** Layer 1 uses local state — `terraform destroy` always works, no deadlocks. Layer 2 is just code deployment — no Terraform, no state, no complexity.

---

## Roles & Responsibilities

| Role | Responsibility | Tools Used |
|------|---------------|-----------|
| **Platform Engineer** | Provisions infra (Layer 1). Manages VM, identity, networking. | Terraform, Azure CLI |
| **Developer** | Pushes app code to `main`. Pipeline handles the rest. | Git, GitHub |
| **Security Engineer** | Reviews PAT scope, NSG rules, UAMI permissions. Audits logs. | Azure Portal, GitHub Settings |
| **The Pipeline** | Authenticates via IMDS, packages code, deploys to App Service. | GitHub Actions, AZ CLI |

### Manual Steps (by design)

| Step | Who | Why manual |
|------|-----|-----------|
| Create GitHub PAT | Security Engineer / Developer | Deliberate security gate. No API for token creation. |
| Register runner (first time) | Platform Engineer | One-time setup. `custom_data` handles it on fresh VMs. |
| Review fork PR settings | Security Engineer | Prevents untrusted code execution on self-hosted runner. |

---

## File Structure

```
12 SelfHosted CICD Bridge/
├── main.tf          # Provider, RG, VNet, Subnet, NSG (local backend)
├── identity.tf      # UAMI + Contributor role at subscription scope
├── vm.tf            # Linux VM (Docker, AZ CLI, GitHub Runner via custom_data)
├── storage.tf       # State storage in separate RG (optional)
├── app.tf           # App Service Plan + Linux Web App
├── variables.tf     # All variable declarations
├── outputs.tf       # VM name, UAMI client ID, storage account name
├── terraform.tfvars # Sensitive values (do NOT commit)
└── README.md        # This file
```

---

## Usage

```bash
# Deploy everything
terraform init
terraform apply -var-file="terraform.tfvars"

# After apply: runner auto-registers via custom_data
# Push to cicd-testing repo → auto-deploys to App Service

# Destroy everything (clean, no deadlocks)
terraform destroy -var-file="terraform.tfvars"
```

## Destroy Behavior

| Command | What gets destroyed |
|---------|-------------------|
| `terraform destroy` | Everything — VM, App, VNet, Storage, both RGs |
| `-target=azurerm_linux_web_app.app` | Only the Web App |
| `-target=azurerm_linux_virtual_machine.vm` | Only the runner VM |

Local state = destroy always works. No remote backend = no deadlock.

---

## Enterprise Considerations

| Concern | Recommendation |
|---------|---------------|
| PAT scope too broad | Use fine-grained PAT scoped to single repo only |
| PAT in tfvars file | Store in Azure Key Vault, reference at apply time |
| Long-lived PAT | Use a GitHub App for short-lived installation tokens |
| Org-wide runners | Register at org level, restrict to specific repos |
| Compliance logging | Enable Azure Activity Log + GitHub Audit Log forwarding |
| Runner hardening | Disable SSH, enable auto-patching, use ephemeral runners |

---

## Lessons Learned

1. **Remote backend chicken-and-egg**: Don't put state storage inside the infra it manages. Use local state for platform layers.
2. **Terraform on small VMs is impractical**: azurerm provider is 300MB. Keep Terraform on your machine, let the pipeline just deploy code.
3. **Azure CLI not pre-installed**: Add `curl -sL https://aka.ms/InstallAzureCLIDeb | bash` to custom_data.
4. **`az login --identity --username` deprecated**: Use `--client-id` in az CLI 2.86+.
5. **GitHub PAT scope**: Runner registration needs **Administration: Read & Write**.
6. **PAT automation is intentionally impossible**: GitHub blocks API-based token creation. This is a security feature, not a limitation.

---

## Prerequisites

- Azure CLI authenticated (`az login`)
- Owner role on subscription (no Entra ID admin needed)
- Terraform >= 1.3
- GitHub PAT with Administration: Read & Write (single repo scope)

## Cost Estimate (Southeast Asia)

| Resource | Monthly Cost |
|----------|-------------|
| VM (B2s_v2) | ~$15 |
| App Service (B1) | ~$13 |
| Storage (LRS) | ~$0.02 |
| VNet/NSG/Identity | Free |
| **Total** | **~$28/month** |
