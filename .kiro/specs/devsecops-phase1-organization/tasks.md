# Implementation Plan: DevSecOps Phase 1 — Organization

## Overview

This plan implements a single PowerShell automation script (`scripts/setup-phase1.ps1`) that provisions all Phase 1 organizational resources using the GitHub CLI. The script creates a GitHub Projects board, two repositories (Platform and Workload), applies branch protection rules, links repositories to the board, and generates comprehensive documentation. Each task builds incrementally toward a fully functional, idempotent setup script.

## Tasks

- [ ] 1. Set up project structure and core script scaffold
  - [x] 1.1 Create the `scripts/` directory and `setup-phase1.ps1` script file with parameter declarations, exit code constants, and the `OperationResult` class definition
    - Define `$ProjectPrefix` (mandatory) and `$GitHubOwner` (optional, default `@me`) parameters
    - Define exit code constants: 0 (success), 1 (operational failure), 2 (validation failure)
    - Create the `OperationResult` class with properties: ResourceType, ResourceName, Status, ErrorMessage
    - Initialize the `$results` collection array
    - _Requirements: 6.1, 6.7, 6.8_

  - [x] 1.2 Implement the Prerequisite Validator function
    - Create `Test-Prerequisites` function that checks: `gh` CLI exists on PATH, version ≥ 2.21.0, `gh auth status` confirms authentication, token scopes include `repo` and `project`
    - On failure: print specific error message with remediation steps and exit with code 2
    - On success: proceed silently without output
    - _Requirements: 6.3, 6.4, 6.5_

  - [x] 1.3 Implement the Summary Reporter function
    - Create `Write-Summary` function that accepts the `$results` array and outputs a formatted table showing Resource Type, Name, and Status for each operation
    - Determine final exit code: 0 if all succeeded, 1 if any failures exist
    - _Requirements: 6.7, 6.8_

- [ ] 2. Implement Project Board Manager
  - [x] 2.1 Implement the `New-ProjectBoard` function for creating/verifying the GitHub Projects (v2) board
    - Check for existing board via `gh project list --owner <owner>` with title match "Azure DevSecOps Pipeline Architecture"
    - If board exists: verify custom fields match required configuration, update if needed, return "AlreadyExisted" or "Updated" status
    - If board does not exist: create via `gh project create`, set description containing "tracks security-integrated delivery across the DevSecOps pipeline lifecycle"
    - _Requirements: 1.1, 1.5, 1.6_

  - [x] 2.2 Implement custom field creation and task item population for the project board
    - Create "Phase" Single Select field with options: "Phase 1: Organization", "Phase 2: Infrastructure", "Phase 3: CI/CD", "Phase 4: Delivery"
    - Verify "Status" field has values: "Todo", "In Progress", "Done"
    - Add minimum 4 draft task items (one per phase) covering infrastructure provisioning, pipeline creation, and security integration, each assigned to its corresponding Phase value
    - _Requirements: 1.2, 1.3, 1.4_

- [ ] 3. Implement Platform Repository Creator
  - [x] 3.1 Implement the `New-PlatformRepository` function with idempotency check and repository creation
    - Check if repo exists via `gh repo view <owner>/<prefix>-platform-infrastructure`
    - If exists: skip creation, return "AlreadyExisted" status
    - If not exists: create via `gh repo create` as public with description, clone locally
    - Handle name conflicts with specific error message and non-zero exit
    - _Requirements: 2.1, 2.10, 2.12_

  - [x] 3.2 Create the Platform Repository directory structure and root module files
    - Create root-level `main.tf` (configuration router consuming child modules), `variables.tf`, `outputs.tf`, `providers.tf` (backend block with `key` omitted)
    - Create `environments/project-alpha-dev.tfvars` example file declaring all root variables
    - Create `terraform.tfvars.example` documenting every variable with comments for purpose, valid values, and sample value
    - Create `.gitignore` for Terraform (`.terraform/`, `*.tfstate`, `*.tfstate.backup`, `.terraform.lock.hcl`, sensitive `*.tfvars`)
    - _Requirements: 2.3, 2.4, 2.5, 2.6, 2.8, 2.9_

  - [x] 3.3 Create the Platform Repository child modules (`modules/network/`, `modules/aks/`, `modules/security/`)
    - Each module contains `main.tf`, `variables.tf`, `outputs.tf`
    - All modules contain zero hardcoded values — every name, SKU, region, address space exposed as a variable
    - Root `main.tf` maps variables from `.tfvars` to module inputs
    - _Requirements: 2.4, 2.7, 2.8, 2.13_

  - [x] 3.4 Create the Platform Repository `.github/workflows/terraform-deploy.yml` pipeline file
    - Include trigger definition
    - Include step demonstrating dynamic state key injection: `terraform init -backend-config="key=<env>.terraform.tfstate"`
    - Include step demonstrating variable file selection: `terraform apply -var-file="environments/<env>.tfvars"`
    - _Requirements: 2.11_

  - [x] 3.5 Create the Platform Repository `README.md` documentation
    - Describe role as reusable infrastructure-as-code store supporting multiple DevSecOps environments
    - Include section on reusable module architecture
    - Include numbered step-by-step procedure (minimum 3 steps) for adding a new environment via `.tfvars`
    - Describe how pipeline injects state key dynamically for environment isolation
    - _Requirements: 2.2, 5.6_

  - [x] 3.6 Commit and push all Platform Repository files to `main` branch
    - Stage all files, commit with descriptive message, push to remote
    - Verify `main` is set as default branch
    - _Requirements: 2.10_

- [ ] 4. Implement Workload Repository Creator
  - [x] 4.1 Implement the `New-WorkloadRepository` function with idempotency check and repository creation
    - Check if repo exists via `gh repo view <owner>/<prefix>-workload`
    - If exists: skip creation, return "AlreadyExisted" status
    - If not exists: create via `gh repo create` as public with description, clone locally
    - Handle name conflicts with specific error message and non-zero exit
    - _Requirements: 3.1, 3.5, 3.6, 3.7_

  - [x] 4.2 Create the Workload Repository file structure and documentation
    - Create `src/.gitkeep` and `docker/.gitkeep` placeholder files
    - Create `.gitignore` for Node.js/Python (`node_modules/`, `__pycache__/`, `.env`, `dist/`, `*.pyc`)
    - Create `README.md` stating repository purpose, listing directory structure, identifying target deployment platform
    - Commit and push to `main` branch, verify `main` is default
    - _Requirements: 3.2, 3.3, 3.4, 3.5_

- [x] 5. Checkpoint - Ensure repository creation logic works
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Implement Branch Protection and Repository Linking
  - [x] 6.1 Implement the `Set-BranchProtection` function using `gh api` REST calls
    - Apply protection to `main` branch via PUT to `repos/<owner>/<repo>/branches/main/protection`
    - Configure: require 1 PR review approval, enforce for admins (no direct pushes), require status checks with placeholder context `ci/pipeline-check`
    - Only execute if target repository was created or already exists
    - On success: output confirmation message per repository
    - On failure: log warning identifying which repository and rule failed, continue with other operations
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

  - [x] 6.2 Implement the `Add-BoardLink` function to link repositories to the project board
    - Link Platform Repository to board via `gh project link <project-number> --owner <owner> --repo <owner>/<repo>`
    - Link Workload Repository to board via same command
    - On success: confirm link operation completed
    - On failure: report error identifying failed repository name and specific failure reason
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 7. Implement main orchestration logic and error handling
  - [x] 7.1 Wire all components together in the main script body with continue-on-failure pattern
    - Call `Test-Prerequisites` first (exit 2 on failure)
    - Call each resource creation function wrapped in try/catch, collecting results
    - Execute dependent operations (branch protection, board links) only if prerequisites met
    - Call `Write-Summary` with collected results
    - Exit with appropriate code (0 or 1)
    - _Requirements: 6.1, 6.2, 6.6, 6.7, 6.8_

  - [x] 7.2 Implement `-DryRun` parameter support
    - Add `-DryRun` switch parameter to script
    - When active: perform all validation checks, print each command that would be executed, make no API calls
    - _Requirements: 6.1_

- [ ] 8. Implement Project-Level Documentation
  - [x] 8.1 Create the project root `README.md` with architecture overview and tools table
    - List all 11 tools by name with one-sentence DevSecOps role description
    - Name all four phases in sequential order with input/output relationships between consecutive phases
    - Create "Tools & Skills" table with columns: Tool Name, DevSecOps Function, Phase Introduced, Role Description (11 rows, no blank cells)
    - _Requirements: 5.1, 5.2_

  - [x] 8.2 Add two-repository structure section and pipeline diagram to root README
    - Name both repositories, state separation-of-concerns rationale
    - Describe Platform Repository reuse via `.tfvars` and dynamic state isolation
    - Create visual/textual diagram labeling all four phases, showing directional flow from commit through deployment/observability, with at least one tool per phase
    - _Requirements: 5.3, 5.4_

  - [x] 8.3 Add Phase 1 tool subsections, time/cost estimation, and step-by-step guide to root README
    - Dedicated subsection for GitHub Projects and GitHub Repositories: purpose, DevSecOps relevance, which subsequent phase consumes output
    - "Time Estimation" section with apply/destroy time per phase
    - "Cost Estimation" section with daily/monthly Azure costs by resource type
    - Write as step-by-step guide from zero to fully deployed pipeline (prerequisites, environment setup, execution order)
    - _Requirements: 5.5, 5.7, 5.8, 5.9_

  - [x] 8.4 Create phase-specific README documentation for the Phase 1 folder
    - Include phase-specific time estimation, cost estimation, tools used with roles, and step-by-step instructions to execute Phase 1 independently
    - _Requirements: 5.10_

- [ ] 9. Implement smoke tests and teardown script
  - [x] 9.1 Create `scripts/test-phase1.ps1` smoke test script for post-execution verification
    - Verify project board exists with correct title and fields
    - Verify both repositories exist with expected names
    - Verify branch protection is active on both repos
    - Verify board links are configured
    - Output pass/fail for each check
    - _Requirements: 6.6, 4.7, 7.3_

  - [x] 9.2 Create `scripts/teardown-phase1.ps1` cleanup script for test environments
    - Remove both repositories via `gh repo delete`
    - Remove project board via `gh project delete`
    - Enable repeatable testing cycles
    - _Requirements: 6.6_

- [x] 10. Final checkpoint - Ensure all components work together
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All tasks use PowerShell as the implementation language, matching the design document
- No property-based tests are included — the feature consists entirely of shell automation and external API interactions with no pure functions suitable for PBT
- The script targets GitHub CLI (`gh`) for all operations; no direct REST API calls except for branch protection (no native `gh` subcommand exists)
- Idempotency is achieved through name-based detection before creation
- The continue-on-failure pattern ensures independent resources don't block each other
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation of the implementation

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["2.1", "3.1", "4.1"] },
    { "id": 3, "tasks": ["2.2", "3.2", "4.2"] },
    { "id": 4, "tasks": ["3.3", "3.4", "3.5"] },
    { "id": 5, "tasks": ["3.6"] },
    { "id": 6, "tasks": ["6.1", "6.2"] },
    { "id": 7, "tasks": ["7.1", "7.2"] },
    { "id": 8, "tasks": ["8.1"] },
    { "id": 9, "tasks": ["8.2", "8.3", "8.4"] },
    { "id": 10, "tasks": ["9.1", "9.2"] }
  ]
}
```
