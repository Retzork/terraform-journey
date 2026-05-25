---
inclusion: auto
---

# Terraform Azure Standards

## Provider
- Use `azurerm` provider version `~> 3.0`
- Always include `features {}` block in provider configuration

## Region
- Default region: `southeastasia`
- Expose as a variable with default value

## Naming Convention
- Pattern: `{resource-type}-{project}-{environment}`
- Examples: `rg-landing-zone-prod`, `vnet-data-platform-dev`, `vm-jumpbox-sea`
- Storage accounts: lowercase, no hyphens (Azure limitation)

## Resource Organization
- All resources must belong to a resource group
- Do NOT use a single `main.tf` — separate files by resource type:
  - `providers.tf` — terraform block, provider config
  - `network.tf` — VNet, subnets, NSG, peering
  - `compute.tf` — VMs, AKS, App Service
  - `identity.tf` — Managed Identity, role assignments
  - `storage.tf` — Storage accounts, containers
  - `database.tf` — SQL, Cosmos, etc.
  - `security.tf` — Firewall, WAF, policies
  - `outputs.tf` — All outputs
  - `variables.tf` — All variable declarations

## Variables
- Use `variables.tf` + `terraform.tfvars` pattern
- Mark passwords and tokens as `sensitive = true`
- Provide sensible defaults where possible

## Backend
- Use local backend unless explicitly needed
- If remote backend is required, put state storage in a separate resource group

## VM Sizing
- Default VM SKU for southeastasia: `Standard_B2s_v2` (cheapest available)
- Before the first `terraform apply` after creating or modifying compute resources, verify SKU availability in the target region using `az vm list-skus --location southeastasia --size Standard_B2s_v2 --output table`
- If the SKU is unavailable or restricted, find the next cheapest available SKU before applying

## Validation After Each Phase
- After completing each task or group of related tasks, run `terraform plan` and `terraform apply` to verify the infrastructure deploys cleanly
- If `terraform apply` produces an error, fix the root cause permanently in the Terraform code — do NOT rely on external scripts, manual steps, or workarounds
- The goal is that `terraform apply` alone is sufficient to provision everything with zero manual intervention
- Scripts are allowed as long as they are triggered by `terraform apply` (e.g., via `local-exec` provisioners or `null_resource` with triggers) — the user should never need to run a script manually
- Every fix must be a permanent code change, not a one-time patch
- MANDATORY: When a phase (or major task group) is complete, run `terraform apply` AND verify the deployed resources work correctly (e.g., `az` CLI checks, connectivity tests, or script execution tests)
- If any error is found during post-phase testing, diagnose and fix it before moving to the next phase — never leave a broken state behind
- For non-Terraform phases (e.g., GitHub setup scripts), run the setup script and verify all resources exist and are correctly configured before marking the phase done

## Documentation
- Every project must include a `README.md` with:
  - Project overview and architecture
  - Tools & Skills table (for CV reference)
  - Time estimation (apply + destroy)
  - Cost estimation (daily + monthly)
  - Usage instructions
  - Verification commands

## DevSecOps Project Documentation Standards
These apply globally to the Azure DevSecOps Pipeline Architecture project (all phases):

### Project Root README (`13 Azure DevSecOps Pipeline Architecture/README.md`)
- Architecture overview listing all 11 tools by name with one-sentence DevSecOps role descriptions
- "Tools & Skills" table: Tool Name, DevSecOps Function, Phase Introduced, Role Description (11 rows, no empty cells)
- Two-repository structure explanation (Platform vs Workload) with separation-of-concerns rationale
- Reusability explanation: how Platform_Repository supports multiple environments via `.tfvars` and dynamic state isolation
- Pipeline flow diagram (Mermaid or text) showing all 4 phases with directional flow and at least one tool per phase
- "Time Estimation" section: estimated apply and destroy time per phase
- "Cost Estimation" section: estimated daily/monthly Azure costs broken down by resource type
- Step-by-step guide usable by anyone to set up their own DevSecOps pipeline from zero (prerequisites, environment setup, execution order)

### Per-Phase README (`Phase X/README.md`)
Each phase folder must include:
- Phase-specific time estimation (apply + destroy)
- Phase-specific cost estimation (daily + monthly)
- Tools used in that phase with their roles explained
- Step-by-step instructions to execute that phase independently
- Educational context: what each tool does, why it's needed, how it connects to other phases

### terraform.tfvars.example
- Every Terraform project must include a `terraform.tfvars.example` at the root level
- Documents every variable with comments explaining purpose, valid values, and a sample value
- Users copy this file to create their own `.tfvars` for new environments
