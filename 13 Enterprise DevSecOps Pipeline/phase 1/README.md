# Phase 1: Organization

Phase 1 establishes the organizational foundation for the Azure DevSecOps Pipeline Architecture. It provisions GitHub-based project management and source control resources using a single automated PowerShell script — no cloud infrastructure is created in this phase.

The script is fully idempotent and can be run by any user with a GitHub account. It creates all resources under the authenticated user's account (or a specified organization).

---

## Quick Start

```powershell
# 1. Install GitHub CLI (if not already installed)
winget install --id GitHub.cli

# 2. Authenticate and add required scopes
gh auth login
gh auth refresh -s repo,project

# 3. Configure git default branch (required for clean repo initialization)
git config --global init.defaultBranch main

# 4. Navigate to this directory
cd "13 Enterprise DevSecOps Pipeline/phase 1"

# 5. Run the setup script
.\scripts\setup-phase1.ps1 -ProjectPrefix "devsecops"

# 6. Verify everything works
.\scripts\test-phase1.ps1 -ProjectPrefix "devsecops"
```

That's it. All resources will be created under your GitHub account.

---

## Prerequisites

### Required Software

| Tool | Minimum Version | Install Command | Purpose |
|------|----------------|-----------------|---------|
| PowerShell | 5.1+ | Pre-installed on Windows | Script execution |
| Git | 2.30+ | `winget install --id Git.Git` | Version control operations |
| GitHub CLI (`gh`) | 2.21+ | `winget install --id GitHub.cli` | GitHub API automation |

### GitHub Authentication

The script requires the GitHub CLI to be authenticated with specific token scopes:

```powershell
# Step 1: Log in to GitHub (choose "GitHub.com" → "HTTPS" → "Login with a web browser")
gh auth login

# Step 2: Add required scopes
gh auth refresh -s repo,project

# Step 3: Verify authentication and scopes
gh auth status
```

You should see output containing:
```
✓ Logged in to github.com account <your-username>
- Token scopes: '...', 'project', 'repo', '...'
```

Both `repo` and `project` must appear in the token scopes.

### Git Configuration

The script creates repositories and pushes to the `main` branch. Ensure your Git is configured to use `main` as the default branch:

```powershell
git config --global init.defaultBranch main
```

Without this, Git may default to `master`, causing push failures.

### Optional: Teardown Scope

If you plan to use the teardown script to delete repositories, you also need the `delete_repo` scope:

```powershell
gh auth refresh -s repo,project,delete_repo
```

---

## What the Script Creates

When you run `setup-phase1.ps1 -ProjectPrefix "devsecops"`, it creates:

| Resource | Name | Description |
|----------|------|-------------|
| **GitHub Projects Board** | Azure DevSecOps Pipeline Architecture | Kanban board with "Phase" custom field and 4 draft task items (one per pipeline phase) |
| **Platform Repository** | `<prefix>-platform-infrastructure` | Terraform IaC repository with reusable modules (network, AKS, security), CI/CD pipeline, and environment configuration |
| **Workload Repository** | `<prefix>-workload` | Application source code repository with `src/`, `docker/` directories and Node.js/Python `.gitignore` |
| **Branch Protection** | Both repos, `main` branch | Requires 1 PR review, enforces for admins, requires `ci/pipeline-check` status |
| **Board Links** | Both repos → board | Repositories linked to the project board for unified tracking |

### Platform Repository Contents

```
<prefix>-platform-infrastructure/
├── main.tf                          # Root module consuming child modules
├── variables.tf                     # All variable declarations (18 variables)
├── outputs.tf                       # Outputs from child modules
├── providers.tf                     # AzureRM provider + backend (key omitted for dynamic injection)
├── terraform.tfvars.example         # Documented variable template
├── environments/
│   └── project-alpha-dev.tfvars     # Example environment file
├── modules/
│   ├── network/                     # Azure VNet + subnets
│   ├── aks/                         # Azure Kubernetes Service cluster
│   └── security/                    # Key Vault + Log Analytics
├── .github/workflows/
│   └── terraform-deploy.yml         # CI/CD with dynamic state key + var-file selection
├── .gitignore                       # Terraform ignore rules
└── README.md                        # Repository documentation
```

### Workload Repository Contents

```
<prefix>-workload/
├── src/.gitkeep                     # Application source placeholder
├── docker/.gitkeep                  # Dockerfile placeholder
├── .gitignore                       # Node.js/Python ignore rules
└── README.md                        # Repository documentation
```

---

## Usage

### Full Execution

```powershell
# Creates all resources under your GitHub account
.\scripts\setup-phase1.ps1 -ProjectPrefix "devsecops"
```

### With a Specific Organization

```powershell
# Creates resources under a GitHub organization
.\scripts\setup-phase1.ps1 -ProjectPrefix "devsecops" -GitHubOwner "my-org"
```

### Dry Run (Preview Only)

Preview what the script will do without making any API calls:

```powershell
.\scripts\setup-phase1.ps1 -ProjectPrefix "devsecops" -DryRun
```

### Custom Project Prefix

The `-ProjectPrefix` parameter controls repository naming:
- `devsecops` → creates `devsecops-platform-infrastructure` and `devsecops-workload`
- `myproject` → creates `myproject-platform-infrastructure` and `myproject-workload`

---

## Verification

### Automated Smoke Test

Run the included test script to verify all resources:

```powershell
.\scripts\test-phase1.ps1 -ProjectPrefix "devsecops"
```

Expected output (all PASS):
```
[PASS] Project board 'Azure DevSecOps Pipeline Architecture' exists
[PASS] Project board has 'Phase' custom field
[PASS] Platform repository 'devsecops-platform-infrastructure' exists
[PASS] Workload repository 'devsecops-workload' exists
[PASS] Branch protection active on 'devsecops-platform-infrastructure/main'
[PASS] Branch protection active on 'devsecops-workload/main'
```

### Manual Verification

```powershell
# Check project board
gh project list --owner @me

# Check repositories
gh repo view <your-username>/devsecops-platform-infrastructure
gh repo view <your-username>/devsecops-workload

# Check branch protection
gh api repos/<your-username>/devsecops-platform-infrastructure/branches/main/protection --jq '.enforce_admins.enabled'
gh api repos/<your-username>/devsecops-workload/branches/main/protection --jq '.required_pull_request_reviews.required_approving_review_count'
```

---

## Teardown (Cleanup)

To remove all Phase 1 resources and start fresh:

```powershell
# Interactive (asks for confirmation)
.\scripts\teardown-phase1.ps1 -ProjectPrefix "devsecops"

# Non-interactive (skips confirmation)
.\scripts\teardown-phase1.ps1 -ProjectPrefix "devsecops" -Force
```

This deletes:
- Both repositories (permanently, including all commits and branches)
- The project board (permanently, including all items)

**Note:** Teardown requires the `delete_repo` scope:
```powershell
gh auth refresh -s delete_repo
```

---

## Troubleshooting

### "GitHub CLI (gh) is not installed or not found on PATH"

Install the GitHub CLI:
```powershell
winget install --id GitHub.cli
```
Then restart your terminal to refresh the PATH.

### "GitHub CLI is not authenticated"

Run:
```powershell
gh auth login
```
Choose GitHub.com → HTTPS → Login with a web browser.

### "GitHub CLI token is missing required scopes: project"

Add the missing scope:
```powershell
gh auth refresh -s repo,project
```

### "error: src refspec main does not match any"

Your Git is defaulting to `master` instead of `main`. Fix with:
```powershell
git config --global init.defaultBranch main
```
Then tear down and re-run the script.

### "Repository name conflict"

A repository with that name already exists under your account. Either:
- Use a different `-ProjectPrefix`
- Delete the existing repo: `gh repo delete <your-username>/<repo-name> --yes`
- Run the teardown script first: `.\scripts\teardown-phase1.ps1 -ProjectPrefix "devsecops" -Force`

### "Branch not found (HTTP 404)" on branch protection

The repository exists but has no `main` branch (it's empty). This happens if the file push failed. Tear down and re-run:
```powershell
.\scripts\teardown-phase1.ps1 -ProjectPrefix "devsecops" -Force
.\scripts\setup-phase1.ps1 -ProjectPrefix "devsecops"
```

### "Problems parsing JSON (HTTP 400)" on branch protection

This was a known issue with PowerShell 5.1's `Set-Content` adding a BOM to JSON files. The script now uses `[System.IO.File]::WriteAllText()` which writes clean UTF-8 without BOM.

---

## How It Works

The setup script follows a **continue-on-failure** pattern:

1. **Validate prerequisites** — checks `gh` CLI, version, auth, scopes (exits immediately on failure)
2. **Create project board** — with "Phase" custom field and description
3. **Add board items** — 4 draft tasks (one per pipeline phase)
4. **Create platform repository** — public repo, cloned to temp directory
5. **Initialize platform files** — Terraform modules, pipeline, README, .gitignore
6. **Push platform files** — commit and push to `main`, verify default branch
7. **Create workload repository** — public repo, cloned to temp directory
8. **Initialize workload files** — src/, docker/, .gitignore, README
9. **Push workload files** — commit and push to `main`
10. **Apply branch protection** — 1 reviewer, admin enforcement, status checks
11. **Link repos to board** — both repos linked for unified tracking
12. **Print summary** — table showing status of each operation

If any step fails, the script continues with independent operations and reports all failures at the end.

---

## Time Estimation

| Operation | Duration |
|-----------|----------|
| Prerequisites validation | ~10 seconds |
| GitHub Projects board creation + fields | ~30 seconds |
| Platform Repository creation + file push | ~2 minutes |
| Workload Repository creation + file push | ~1 minute |
| Branch protection configuration | ~20 seconds |
| Repository-to-board linking | ~15 seconds |
| **Total Phase 1 execution** | **~5 minutes** |

## Cost Estimation

| Resource | Cost |
|----------|------|
| GitHub Projects board | Free |
| Public repositories (×2) | Free |
| Branch protection rules | Free |
| GitHub CLI usage | Free |
| **Total Phase 1 cost** | **$0/month** |

Phase 1 has zero Azure costs. Azure costs begin in Phase 2.

---

## Idempotency

The script is safe to run multiple times:

| Resource | If Already Exists |
|----------|-------------------|
| Project board | Verifies configuration, updates if needed |
| Repositories | Skips creation, reports "AlreadyExisted" |
| Branch protection | Re-applies (PUT is idempotent) |
| Board links | Re-links silently |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All resources created or verified successfully |
| `1` | One or more operational failures (partial success — check summary table) |
| `2` | Prerequisite validation failure (script exits immediately) |

---

## Directory Structure

```
phase 1/
├── README.md                    # This file
└── scripts/
    ├── setup-phase1.ps1         # Main setup script (~2800 lines)
    ├── test-phase1.ps1          # Smoke test script (8 verification checks)
    └── teardown-phase1.ps1      # Cleanup script for repeatable testing
```

---

## What Comes Next

Phase 1 outputs feed directly into Phase 2 (Infrastructure):

- The **Platform Repository** contains Terraform modules that Phase 2 executes with `terraform apply`
- The **Workload Repository** scaffold is where Phase 3 (CI/CD) builds and deploys from
- The **Branch protection rules** enforce code review gates that Phase 3 pipelines respect
- The **Project board** tracks progress across all four phases
