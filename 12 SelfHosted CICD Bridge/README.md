# 12 — Self-Hosted CI/CD Bridge

Deploy to Azure from GitHub Actions **without a Service Principal or OIDC** — using a Self-Hosted Runner VM with a User-Assigned Managed Identity.

## The Problem

You have **Owner** rights on your Azure subscription but **no Entra ID tenant permissions**. This means you cannot create App Registrations (Service Principals) or configure OIDC federation for GitHub. Standard CI/CD authentication methods are blocked.

## The Solution

A Linux VM running the GitHub Actions Runner agent, with a Managed Identity attached. The VM authenticates to Azure locally via the Instance Metadata Service (IMDS) — no secrets stored anywhere.

## Architecture

```
┌─────────────────────┐              ┌────────────────────────────────────────┐
│   GitHub (Public)    │              │         Azure Subscription              │
│                      │              │                                          │
│  Retzork/cicd-testing│              │  ┌──────────────────────────────────┐   │
│  ├── app/            │              │  │  vm-github-runner (B2s, Ubuntu)  │   │
│  │   ├── index.html  │   push to   │  │  ├── GitHub Runner Agent         │   │
│  │   └── server.js   │────main────▶│  │  ├── Docker Engine               │   │
│  └── .github/        │              │  │  ├── Azure CLI                   │   │
│      └── workflows/  │              │  │  └── UAMI: uami-github-runner    │   │
│          └── deploy.yml             │  │         │                         │   │
│                      │              │  │         │ az login --identity     │   │
│  runs-on: self-hosted│              │  │         ▼                         │   │
└─────────────────────┘              │  │  IMDS (169.254.169.254)           │   │
                                      │  │         │ Bearer Token            │   │
                                      │  │         ▼                         │   │
                                      │  │  az webapp deploy ───────────┐   │   │
                                      │  └──────────────────────────────┼───┘   │
                                      │                                 ▼       │
                                      │  ┌──────────────────────────────────┐   │
                                      │  │  app-cicd-bridge-2026-artha      │   │
                                      │  │  (App Service, Node 18, Linux)   │   │
                                      │  └──────────────────────────────────┘   │
                                      └────────────────────────────────────────┘
```

## How It Works

1. Developer pushes code to `main` branch on GitHub
2. GitHub sees `.github/workflows/deploy.yml` and queues the job
3. Job is routed to `runs-on: self-hosted` — your registered VM runner
4. Runner agent on the VM picks up the job (it polls GitHub continuously)
5. Pipeline runs `az login --identity --client-id <UAMI_CLIENT_ID>`
6. Azure CLI calls IMDS at `169.254.169.254` to get a Bearer token
7. Pipeline zips the app and deploys via `az webapp deploy`
8. Site is live — no secrets were used at any point

## Why Managed Identity Over Service Principal

| Concern | Service Principal | Managed Identity |
|---------|------------------|-----------------|
| Secrets | Client secret stored in GitHub/KeyVault | **No secrets exist** |
| Rotation | Must rotate every 1-2 years | **Nothing to rotate** |
| Leakage risk | Secret in env vars, pipelines, repos | **Impossible to leak** |
| Entra ID permissions | Requires App Registration rights | **Only needs RBAC** |
| Token acquisition | OAuth2 client_credentials flow | **IMDS local HTTP call** |
| Blast radius | Secret usable from anywhere | **Only from the VM** |

## IMDS — The Secret Sauce

The Instance Metadata Service is a REST endpoint at `169.254.169.254` (link-local, unreachable from the internet). When the runner needs a token:

```
GET http://169.254.169.254/metadata/identity/oauth2/token
    ?api-version=2018-02-01
    &resource=https://management.azure.com/
    &client_id=<UAMI_CLIENT_ID>
Header: Metadata: true
```

Azure returns a short-lived Bearer token (24h, auto-refreshed). No secrets are stored, transmitted, or rotatable.

## File Structure

```
12 SelfHosted CICD Bridge/
├── main.tf          # Provider, backend, Resource Group, VNet, Subnet, NSG
├── identity.tf      # User-Assigned Managed Identity + Contributor role
├── vm.tf            # Linux VM with custom_data (Docker, AZ CLI, GH Runner)
├── storage.tf       # Storage Account for Terraform remote state
├── app.tf           # App Service Plan + Linux Web App (Node 18)
├── variables.tf     # All variable declarations
├── outputs.tf       # Useful output values (URLs, IDs)
├── terraform.tfvars # Variable values (sensitive — do NOT commit)
└── README.md        # This file
```

## Resources Deployed

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `rg-cicd-bridge` | Container for all resources |
| Managed Identity | `uami-github-runner` | Secretless auth (Contributor @ subscription) |
| Virtual Network | `vnet-cicd-bridge` (10.0.0.0/16) | Network isolation |
| Subnet | `snet-runner` (10.0.1.0/24) | Runner VM subnet |
| NSG | `nsg-runner-subnet` | Deny all inbound from internet |
| Linux VM | `vm-github-runner` (Standard_B2s_v2) | Self-hosted runner host |
| Storage Account | `arthatfstatecicdbrg2026` | Terraform remote state |
| App Service Plan | `asp-cicd-bridge` (B1 Linux) | Hosting plan |
| Web App | `app-cicd-bridge-2026-artha` | Deployed application |

## GitHub Repository

The application code and workflow live in a separate repo:

**https://github.com/Retzork/cicd-testing**

```
cicd-testing/
├── app/
│   ├── index.html    # Static web page
│   └── server.js     # Node.js HTTP server
└── .github/
    └── workflows/
        └── deploy.yml  # CI/CD pipeline (runs-on: self-hosted)
```

## Pipeline (deploy.yml)

```yaml
runs-on: self-hosted

steps:
  - az login --identity --client-id <UAMI_CLIENT_ID>   # IMDS token
  - zip app/ → deploy.zip                              # Package
  - az webapp deploy --src-path deploy.zip --type zip  # Deploy
```

No GitHub Secrets configured. The subscription ID and client ID in the YAML are public identifiers — useless without being on the VM.

## Security Model

| Layer | Protection |
|-------|-----------|
| Network | NSG denies all inbound internet traffic to runner subnet |
| Identity | UAMI token only obtainable from VM (IMDS is link-local) |
| Scope | Contributor role (not Owner) — cannot modify IAM |
| Runner | Only `main` branch pushes trigger workflows |
| State | Remote state in private blob container, TLS 1.2 enforced |
| VM | No public IP, password auth (SSH key recommended for production) |

**Important:** In GitHub repo Settings → Actions → General, disable "Fork pull request workflows from outside collaborators" to prevent untrusted code from running on your runner.

## Prerequisites

- Azure CLI authenticated (`az login`)
- Owner role on the target subscription
- Terraform >= 1.3
- GitHub PAT with **Administration: Read & Write** repository permission

## Usage

```bash
# Initialize (connects to remote backend in Azure Storage)
terraform init

# Plan
terraform plan -var-file="terraform.tfvars"

# Apply
terraform apply -var-file="terraform.tfvars" -auto-approve

# Outputs
terraform output
```

## Verification Commands

```bash
# Verify UAMI + role assignment
az role assignment list --assignee $(az identity show -n uami-github-runner -g rg-cicd-bridge --query principalId -o tsv) --role Contributor -o table

# Verify VM identity
az vm show -n vm-github-runner -g rg-cicd-bridge --query "identity.type" -o tsv

# Verify runner service (from VM)
az vm run-command invoke -g rg-cicd-bridge -n vm-github-runner --command-id RunShellScript --scripts "systemctl is-active actions.runner.*"

# Verify web app
curl -s https://app-cicd-bridge-2026-artha.azurewebsites.net | grep "<title>"

# Verify remote state
az storage blob list --account-name arthatfstatecicdbrg2026 --container-name tfstate -o table
```

## Lessons Learned

1. **Azure CLI must be explicitly installed** on the runner VM — it's not included in Ubuntu base images
2. **`zip` package** is not pre-installed on Ubuntu Server — add it to custom_data
3. **`az login --identity --username`** is deprecated in az CLI 2.86+ — use `--client-id` instead
4. **GitHub PAT scope** for runner registration requires **Administration: Read & Write** (fine-grained tokens)
5. **Terraform remote backend** creates a chicken-and-egg problem — deploy with local state first, then migrate

## Cost Estimate (Southeast Asia)

| Resource | Monthly Cost |
|----------|-------------|
| VM (B2s_v2) | ~$15 |
| App Service (B1) | ~$13 |
| Storage (LRS, minimal) | ~$0.02 |
| VNet/NSG/Identity | Free |
| **Total** | **~$28/month** |

## Cleanup

```bash
terraform destroy -var-file="terraform.tfvars" -auto-approve
```

Note: Remove the runner from GitHub Settings → Actions → Runners before destroying, or it will show as offline.
