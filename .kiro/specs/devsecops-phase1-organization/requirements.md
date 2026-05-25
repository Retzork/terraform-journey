# Requirements Document

## Introduction

Phase 1 of the Azure DevSecOps Pipeline Architecture establishes the organizational foundation for a four-phase learning project. This phase focuses on project management (GitHub Projects) and code management (GitHub Repositories) — the two pillars that enable structured, security-integrated delivery in enterprise environments. No cloud infrastructure is provisioned in this phase; the goal is to set up the planning board, repositories, branch governance, and documentation that all subsequent phases depend on.

This is a learning-focused portfolio project. Each component explains what it does, why it matters in DevSecOps, and how it connects to the broader 11-tool architecture.

## Glossary

- **GitHub_Projects_Board**: A GitHub Projects (v2) board used as an agile planning tool to track tasks across the four deployment phases of the DevSecOps pipeline
- **Platform_Repository**: A reusable GitHub repository that stores modular Terraform infrastructure-as-code configurations, designed so that a new DevSecOps environment can be provisioned by adding a single `.tfvars` file and running the pipeline with a dynamic state key
- **Workload_Repository**: A GitHub repository that stores application source code, Dockerfiles, and CI/CD workflow definitions
- **Branch_Protection_Rule**: A GitHub repository setting that enforces conditions (such as required status checks or review approvals) before code can be merged into a protected branch
- **GitHub_CLI**: The `gh` command-line tool used to automate GitHub operations including repository creation, project board management, and branch protection configuration
- **Phase_Column**: A column or status field on the GitHub Projects board representing one of the four deployment phases
- **README_Documentation**: Markdown documentation files that explain architecture, tools, skills, and usage instructions for the project
- **Child_Module**: A self-contained Terraform module under the `modules/` directory that accepts all configuration via variables and contains zero hardcoded values
- **State_Isolation**: The practice of using a unique Terraform state file key per environment, enabling multiple deployments from the same codebase without resource conflicts
- **Configuration_Router**: The root `main.tf` file that consumes child modules and passes variables from `.tfvars` files to module inputs without containing resource definitions itself

## Requirements

### Requirement 1: GitHub Projects Board Creation

**User Story:** As a DevSecOps engineer, I want an agile project board that tracks all deployment phases, so that I can demonstrate structured project management practices to recruiters and manage work across the pipeline lifecycle.

#### Acceptance Criteria

1. WHEN the setup script is executed, THE GitHub_CLI SHALL create a GitHub Projects (v2) board named "Azure DevSecOps Pipeline Architecture" linked to the target GitHub repository
2. THE GitHub_Projects_Board SHALL contain a Single Select custom field named "Phase" with exactly four options: "Phase 1: Organization", "Phase 2: Infrastructure", "Phase 3: CI/CD", and "Phase 4: Delivery"
3. THE GitHub_Projects_Board SHALL contain a "Status" field with values: "Todo", "In Progress", and "Done"
4. WHEN the board is created or updated, THE GitHub_CLI SHALL populate a minimum of one task item per phase, with at least four total task items covering infrastructure provisioning, pipeline creation, and security integration, each assigned to its corresponding Phase field value
5. THE GitHub_Projects_Board SHALL include a description that contains the text "tracks security-integrated delivery across the DevSecOps pipeline lifecycle"
6. IF the GitHub Projects board named "Azure DevSecOps Pipeline Architecture" already exists when the setup script is executed, THEN THE GitHub_CLI SHALL check whether the existing board matches the required configuration (correct custom fields, status values, and minimum task items), update the board to match the required configuration if discrepancies are found, and report the board status without creating a duplicate

### Requirement 2: Platform Repository Initialization (Reusable Architecture)

**User Story:** As a DevSecOps engineer, I want a dedicated, reusable repository for Terraform configurations, so that the same infrastructure codebase can provision multiple DevSecOps environments by changing only a `.tfvars` file — demonstrating enterprise-grade modularity.

#### Acceptance Criteria

1. WHEN the setup script is executed, THE GitHub_CLI SHALL create a public repository named using the pattern `<project-prefix>-platform-infrastructure` (e.g., `devsecops-platform-infrastructure`) where the project prefix is provided as a script input parameter
2. THE Platform_Repository SHALL contain a README_Documentation file explaining its role as a reusable infrastructure-as-code store that supports multiple DevSecOps environments
3. THE Platform_Repository SHALL contain a `.gitignore` file configured for Terraform projects (ignoring `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `.terraform.lock.hcl`, and sensitive `*.tfvars` files)
4. THE Platform_Repository SHALL use a modular directory structure with a root module containing at minimum `main.tf`, `variables.tf`, `outputs.tf`, and `providers.tf`, and child modules under a `modules/` directory (e.g., `modules/network/`, `modules/aks/`, `modules/security/`) where each child module contains at minimum `main.tf`, `variables.tf`, and `outputs.tf`
5. THE Platform_Repository SHALL contain an `environments/` directory with at least one example `.tfvars` file (e.g., `environments/project-alpha-dev.tfvars`) that declares all variables required by the root module
6. THE Platform_Repository SHALL contain a `terraform.tfvars.example` file at the root level that documents every variable with comments explaining its purpose, valid values, and a sample value — users copy this file to create their own `.tfvars` for new environments
7. THE Platform_Repository child modules SHALL contain zero hardcoded values — every name, SKU, region, and address space SHALL be exposed as a variable
8. THE Platform_Repository root `main.tf` SHALL consume child modules and map variables from `.tfvars` files to module inputs
9. THE Platform_Repository `providers.tf` SHALL configure the backend block with the `key` parameter omitted, enabling dynamic state isolation at pipeline execution time
10. THE Platform_Repository SHALL be initialized with a `main` branch as the default branch
11. THE Platform_Repository SHALL include a `.github/workflows/` directory with a pipeline YAML file that contains at minimum: a trigger definition, a step demonstrating dynamic state key injection (`terraform init -backend-config="key=<env>.terraform.tfstate"`), and a step demonstrating variable file selection (`terraform apply -var-file="environments/<env>.tfvars"`)
12. IF a repository with the same name already exists in the target GitHub account, THEN THE setup script SHALL display an error message indicating the repository name conflict and SHALL exit without modifying the existing repository
12. IF repository creation fails for reasons other than a name conflict (network issues, insufficient permissions, invalid project prefix, or API errors), THEN THE setup script SHALL display an error message identifying the specific failure reason and SHALL exit with a non-zero status code without leaving partially created resources
13. THE Platform_Repository SHALL be structured so that provisioning a new, fully isolated DevSecOps environment requires only adding a new `.tfvars` file to the `environments/` directory and executing the pipeline with the corresponding environment name — no modifications to module source code, root configuration, or pipeline definitions SHALL be required

### Requirement 3: Workload Repository Initialization

**User Story:** As a DevSecOps engineer, I want a dedicated repository for application source code and Dockerfiles, so that workload artifacts are managed independently from infrastructure configurations.

#### Acceptance Criteria

1. WHEN the setup script is executed, THE GitHub_CLI SHALL create a public repository named using the pattern `{project-name}-workload` where `{project-name}` matches the project identifier used across the pipeline
2. THE Workload_Repository SHALL contain a README_Documentation file that states the repository purpose as the application code and container image source for the DevSecOps pipeline, lists the directory structure, and identifies the target deployment platform
3. THE Workload_Repository SHALL contain a `.gitignore` file configured for Node.js and Python projects (ignoring `node_modules/`, `__pycache__/`, `.env`, `dist/`, and `*.pyc`)
4. THE Workload_Repository SHALL contain a `src/` directory for application source code and a `docker/` directory for Dockerfiles, each containing a placeholder `.gitkeep` file
5. THE Workload_Repository SHALL be initialized with a `main` branch as the default branch
6. IF the repository name already exists under the target GitHub account, THEN THE GitHub_CLI SHALL exit with a non-zero status code and display an error message indicating the naming conflict without modifying the existing repository
7. IF repository creation fails for reasons other than a name conflict (network issues, insufficient permissions, or API errors), THEN THE setup script SHALL display an error message identifying the specific failure reason and SHALL exit with a non-zero status code

### Requirement 4: Branch Protection Rules

**User Story:** As a DevSecOps engineer, I want branch protection rules on both repositories, so that code governance is enforced and merges require passing pipeline checks — demonstrating enterprise-grade access control.

#### Acceptance Criteria

1. WHEN both repositories are created, THE GitHub_CLI SHALL configure branch protection rules on the `main` branch of the Platform_Repository
2. WHEN both repositories are created, THE GitHub_CLI SHALL configure branch protection rules on the `main` branch of the Workload_Repository
3. THE Branch_Protection_Rule SHALL require a minimum of 1 pull request review approval before merging to `main`
4. THE Branch_Protection_Rule SHALL prevent direct pushes to the `main` branch by enforcing pull-request-only merges for all users including administrators
5. THE Branch_Protection_Rule SHALL require status checks to pass before merging, with at least one status check context name configured as a placeholder until CI pipelines are created in Phase 3
6. IF the GitHub_CLI encounters a permissions error when setting branch protection on any repository that actually prevents configuration from succeeding, THEN THE setup script SHALL log a warning message indicating which repository and which protection rule failed; IF the logging mechanism itself fails, THEN THE script SHALL exit with a non-zero status code
7. WHEN branch protection rules are successfully applied to a repository, THE setup script SHALL output a confirmation message for that repository indicating that branch protection is active on `main`, with confirmations output per repository as each succeeds

### Requirement 5: Phase 1 Documentation

**User Story:** As a DevSecOps engineer building a portfolio piece, I want Phase 1 documentation that explains the organizational tools and repository architecture, so that reviewers understand the project foundation and can follow along.

#### Acceptance Criteria

1. THE README_Documentation for Phase 1 SHALL contain a dedicated subsection for each Phase 1 tool (GitHub Projects and GitHub Repositories) that states the tool's purpose, its DevSecOps relevance, and identifies which subsequent phase consumes its output
2. THE README_Documentation for the Platform_Repository SHALL contain a section describing the reusable module architecture, a numbered step-by-step procedure (minimum 3 steps) for adding a new environment by creating a `.tfvars` file, and a description of how the pipeline injects the state key dynamically to isolate environment state
3. THE project root README SHALL be created during Phase 1 following the global documentation standards defined in steering (11-tool overview, Tools & Skills table, pipeline diagram, time/cost estimation, step-by-step guide)

### Requirement 6: Setup Automation Script

**User Story:** As a DevSecOps engineer, I want a single automation script that provisions all Phase 1 resources, so that the organizational foundation can be reproduced consistently and demonstrates infrastructure-as-code principles even for non-cloud resources.

#### Acceptance Criteria

1. THE setup script SHALL be executable from the Phase 1 directory using a single command with no interactive prompts required during execution
2. THE setup script SHALL use the GitHub_CLI to perform all GitHub operations (repository creation, project board setup, branch protection configuration)
3. WHEN the setup script is executed, THE script SHALL validate that the GitHub_CLI is installed, meets a minimum version requirement, and that the current session is authenticated with sufficient permissions (repo, project scopes) before proceeding with any resource creation
4. IF the GitHub_CLI is not installed or not authenticated, THEN THE setup script SHALL display an error message indicating the specific failure reason (missing CLI or missing authentication), provide actionable remediation steps, and exit with a non-zero exit code distinct from operational failure codes (validation failures SHALL use exit code 2, operational failures SHALL use exit code 1)
5. THE setup script SHALL only display error messages and remediation steps when validation actually fails — successful validation SHALL proceed silently to resource creation without displaying error output or validation-related messages
6. THE setup script SHALL be idempotent — running the script multiple times SHALL detect already-existing resources by name, skip their creation, and produce the same end state without creating duplicate resources or returning errors for pre-existing resources
7. WHEN the setup script completes successfully, THE script SHALL output a summary listing each resource type, resource name, and creation status (created or already existed) and exit with exit code 0
8. IF a resource creation operation fails during execution, THEN THE setup script SHALL log the failed operation and resource name, continue provisioning remaining independent resources, and exit with a non-zero exit code (exit code 1) after outputting a failure summary identifying all failed operations

### Requirement 7: Linking Repositories to Project Board

**User Story:** As a DevSecOps engineer, I want both repositories linked to the project board, so that issues and pull requests from either repository appear on the agile board for unified tracking.

#### Acceptance Criteria

1. WHEN both repositories and the project board are created, THE GitHub_CLI SHALL link the Platform_Repository to the GitHub_Projects_Board and confirm the link operation completed successfully
2. WHEN both repositories and the project board are created, THE GitHub_CLI SHALL link the Workload_Repository to the GitHub_Projects_Board and confirm the link operation completed successfully
3. WHEN both repositories are linked to the GitHub_Projects_Board, THE GitHub_Projects_Board SHALL display issues and pull requests from both the Platform_Repository and the Workload_Repository within a single board view
4. IF a repository linking operation fails, THEN THE GitHub_CLI SHALL report an error message that specifically identifies the failed repository by name and provides the specific failure reason (permissions, network, API error, or repository not found) — generic error messages without repository identification or failure reason SHALL NOT be used; IF the error reporting mechanism fails to generate a message, THEN THE system SHALL produce a fallback error indication with at minimum the operation name and a non-zero exit code
