#Requires -Version 5.1
<#
.SYNOPSIS
    Phase 1 Setup Script — DevSecOps Pipeline Organization
.DESCRIPTION
    Provisions all Phase 1 organizational resources using the GitHub CLI:
    - GitHub Projects (v2) board with custom fields and task items
    - Platform Infrastructure repository (reusable Terraform modules)
    - Workload repository (application source and Dockerfiles)
    - Branch protection rules on both repositories
    - Repository-to-board linkages
.PARAMETER ProjectPrefix
    Mandatory. The project prefix used for naming repositories (e.g., "devsecops").
    Repositories will be named: <ProjectPrefix>-platform-infrastructure and <ProjectPrefix>-workload.
.PARAMETER GitHubOwner
    Optional. The GitHub user or organization that owns the resources.
    Defaults to "@me" (the currently authenticated user).
.PARAMETER DryRun
    Optional switch. When specified, the script performs all validation checks but makes
    no actual API calls. Each command that would be executed is printed in [DRY RUN] format.
.EXAMPLE
    .\setup-phase1.ps1 -ProjectPrefix "devsecops"
.EXAMPLE
    .\setup-phase1.ps1 -ProjectPrefix "devsecops" -GitHubOwner "my-org"
.EXAMPLE
    .\setup-phase1.ps1 -ProjectPrefix "devsecops" -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPrefix,

    [Parameter(Mandatory = $false)]
    [string]$GitHubOwner = "@me",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# ==============================================================================
# Exit Code Constants
# ==============================================================================
$EXIT_SUCCESS            = 0  # All resources created/verified successfully
$EXIT_OPERATIONAL_FAILURE = 1  # One or more operational failures (resource creation failed)
$EXIT_VALIDATION_FAILURE  = 2  # Prerequisite validation failure (CLI missing, not authenticated, insufficient scopes)

# ==============================================================================
# DryRun Mode
# ==============================================================================
# Script-level variable that functions check to determine if they should execute
# or just print what they would do. Set from the -DryRun switch parameter.
$script:DryRun = $DryRun.IsPresent

if ($script:DryRun) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  DRY RUN MODE — No changes will be made" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
}

# ==============================================================================
# Data Model: OperationResult
# ==============================================================================
class OperationResult {
    [string]$ResourceType    # "ProjectBoard", "Repository", "BranchProtection", "BoardLink"
    [string]$ResourceName    # Human-readable name of the resource
    [string]$Status          # "Created", "AlreadyExisted", "Updated", "Failed"
    [string]$ErrorMessage    # Empty on success, failure reason on error
}

# ==============================================================================
# Summary Reporter
# ==============================================================================
function Write-Summary {
    <#
    .SYNOPSIS
        Outputs a formatted summary table of all operation results and determines the exit code.
    .DESCRIPTION
        Accepts the results array and displays a table showing Resource Type, Name, and Status
        for each operation. Returns exit code 0 if all operations succeeded, or 1 if any failures exist.
    .PARAMETER Results
        Array of OperationResult objects collected during script execution.
    .OUTPUTS
        [int] Exit code: 0 (all succeeded) or 1 (one or more failures).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results
    )

    Write-Host ""
    Write-Host "+--------------------+-----------------------------+----------------+"
    Write-Host "| Phase 1 Setup Summary                                              |"
    Write-Host "+--------------------+-----------------------------+----------------+"
    Write-Host ("| {0,-18} | {1,-27} | {2,-14} |" -f "Resource Type", "Name", "Status")
    Write-Host "+--------------------+-----------------------------+----------------+"

    foreach ($result in $Results) {
        $name = $result.ResourceName
        if ($name.Length -gt 27) {
            $name = $name.Substring(0, 24) + "..."
        }
        $status = $result.Status
        if ($status.Length -gt 14) {
            $status = $status.Substring(0, 11) + "..."
        }
        $type = $result.ResourceType
        if ($type.Length -gt 18) {
            $type = $type.Substring(0, 15) + "..."
        }
        Write-Host ("| {0,-18} | {1,-27} | {2,-14} |" -f $type, $name, $status)
    }

    Write-Host "+--------------------+-----------------------------+----------------+"

    # Determine if any failures occurred
    $failures = $Results | Where-Object { $_.Status -eq "Failed" }

    if ($failures -and $failures.Count -gt 0) {
        Write-Host ""
        Write-Host "[ERROR] The following operations failed:" -ForegroundColor Red
        foreach ($failure in $failures) {
            Write-Host ("  - {0} ({1}): {2}" -f $failure.ResourceType, $failure.ResourceName, $failure.ErrorMessage) -ForegroundColor Red
        }
        return $EXIT_OPERATIONAL_FAILURE
    }

    Write-Host ""
    Write-Host "All Phase 1 resources provisioned successfully." -ForegroundColor Green
    return $EXIT_SUCCESS
}

# ==============================================================================
# Prerequisite Validator
# ==============================================================================
function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validates that the environment meets all prerequisites for script execution.
    .DESCRIPTION
        Checks that the GitHub CLI (gh) is installed, meets the minimum version requirement,
        is authenticated, and has the required token scopes. Exits with code 2 on any failure.
    #>

    # --- Check 1: gh CLI exists on PATH ---
    $ghCommand = Get-Command -Name "gh" -ErrorAction SilentlyContinue
    if (-not $ghCommand) {
        Write-Host "[ERROR] GitHub CLI (gh) is not installed or not found on PATH." -ForegroundColor Red
        Write-Host "        Remediation: Install the GitHub CLI from https://cli.github.com/" -ForegroundColor Yellow
        Write-Host "        On Windows: winget install --id GitHub.cli" -ForegroundColor Yellow
        Write-Host "        On macOS:   brew install gh" -ForegroundColor Yellow
        Write-Host "        On Linux:   See https://github.com/cli/cli/blob/trunk/docs/install_linux.md" -ForegroundColor Yellow
        exit $EXIT_VALIDATION_FAILURE
    }

    # --- Check 2: gh version >= 2.21.0 ---
    $versionOutput = & gh --version 2>&1
    $versionMatch = [regex]::Match($versionOutput, "(\d+)\.(\d+)\.(\d+)")
    if (-not $versionMatch.Success) {
        Write-Host "[ERROR] Unable to determine GitHub CLI version." -ForegroundColor Red
        Write-Host "        Remediation: Ensure 'gh --version' returns a valid version string." -ForegroundColor Yellow
        exit $EXIT_VALIDATION_FAILURE
    }

    $major = [int]$versionMatch.Groups[1].Value
    $minor = [int]$versionMatch.Groups[2].Value
    $patch = [int]$versionMatch.Groups[3].Value

    $meetsMinimum = ($major -gt 2) -or
                    ($major -eq 2 -and $minor -gt 21) -or
                    ($major -eq 2 -and $minor -eq 21 -and $patch -ge 0)

    if (-not $meetsMinimum) {
        Write-Host "[ERROR] GitHub CLI version $major.$minor.$patch is below the minimum required version 2.21.0." -ForegroundColor Red
        Write-Host "        Remediation: Upgrade the GitHub CLI to version 2.21.0 or later." -ForegroundColor Yellow
        Write-Host "        On Windows: winget upgrade --id GitHub.cli" -ForegroundColor Yellow
        Write-Host "        On macOS:   brew upgrade gh" -ForegroundColor Yellow
        Write-Host "        On Linux:   See https://github.com/cli/cli/blob/trunk/docs/install_linux.md" -ForegroundColor Yellow
        exit $EXIT_VALIDATION_FAILURE
    }

    # --- Check 3: gh auth status confirms authentication ---
    $authOutput = & gh auth status 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] GitHub CLI is not authenticated." -ForegroundColor Red
        Write-Host "        Remediation: Run 'gh auth login' to authenticate with your GitHub account." -ForegroundColor Yellow
        exit $EXIT_VALIDATION_FAILURE
    }

    # --- Check 4: Token scopes include 'repo' and 'project' ---
    $scopesLine = $authOutput | Select-String -Pattern "Token scopes"
    $hasRepo = $false
    $hasProject = $false

    if ($scopesLine) {
        $scopesText = $scopesLine.ToString()
        $hasRepo = $scopesText -match "\brepo\b"
        $hasProject = $scopesText -match "\bproject\b"
    }

    if (-not $hasRepo -or -not $hasProject) {
        $missingScopes = @()
        if (-not $hasRepo) { $missingScopes += "repo" }
        if (-not $hasProject) { $missingScopes += "project" }
        $missingScopesStr = $missingScopes -join ", "

        Write-Host "[ERROR] GitHub CLI token is missing required scopes: $missingScopesStr" -ForegroundColor Red
        Write-Host "        Remediation: Run 'gh auth refresh -s repo,project' to add the required scopes." -ForegroundColor Yellow
        exit $EXIT_VALIDATION_FAILURE
    }

    # All checks passed — proceed silently
}

# ==============================================================================
# Platform Repository Creator
# ==============================================================================
function New-PlatformRepository {
    <#
    .SYNOPSIS
        Creates the Platform Infrastructure repository with idempotency check.
    .DESCRIPTION
        Checks if the platform repository already exists. If it does, returns an
        OperationResult with "AlreadyExisted" status. If not, creates the repository
        as public with a descriptive message and clones it locally to a temporary
        working directory.
    .PARAMETER Owner
        The GitHub user or organization that owns the repository.
    .PARAMETER ProjectPrefix
        The project prefix used for naming the repository.
    .OUTPUTS
        [OperationResult] Result of the repository creation operation.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$ProjectPrefix
    )

    $repoName = "$ProjectPrefix-platform-infrastructure"

    # --- DryRun Check ---
    if ($script:DryRun) {
        Write-Host "[DRY RUN] Would create repository '$Owner/$repoName' (public)" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would clone repository to temporary working directory" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would initialize with Terraform file structure and push to main" -ForegroundColor Yellow
        $result = [OperationResult]::new()
        $result.ResourceType = "Repository"
        $result.ResourceName = $repoName
        $result.Status = "DryRun"
        $result.ErrorMessage = ""
        return $result
    }

    # Resolve the owner for gh commands (handle @me)
    if ($Owner -eq "@me") {
        $resolvedOwner = (& gh api user --jq '.login' 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Failed to resolve GitHub username from '@me'." -ForegroundColor Red
            $result = [OperationResult]::new()
            $result.ResourceType = "Repository"
            $result.ResourceName = $repoName
            $result.Status = "Failed"
            $result.ErrorMessage = "Unable to resolve authenticated user."
            return $result
        }
    } else {
        $resolvedOwner = $Owner
    }

    $fullRepoName = "$resolvedOwner/$repoName"

    # --- Idempotency Check: Does the repository already exist? ---
    $viewOutput = & gh repo view $fullRepoName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[INFO] Repository '$fullRepoName' already exists. Skipping creation." -ForegroundColor Cyan
        $result = [OperationResult]::new()
        $result.ResourceType = "Repository"
        $result.ResourceName = $repoName
        $result.Status = "AlreadyExisted"
        $result.ErrorMessage = ""
        return $result
    }

    # --- Create the repository ---
    $description = "Reusable Terraform infrastructure-as-code repository for the DevSecOps pipeline. Supports multiple environments via .tfvars files and dynamic state isolation."

    # Create a temporary working directory for cloning
    $tempWorkDir = Join-Path ([System.IO.Path]::GetTempPath()) "phase1-setup-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempWorkDir -Force | Out-Null

    $createOutput = & gh repo create $fullRepoName --public --description $description --clone 2>&1
    $createExitCode = $LASTEXITCODE

    if ($createExitCode -ne 0) {
        $errorString = $createOutput | Out-String

        # Check for name conflict (repository already exists error from API)
        if ($errorString -match "Name already exists" -or $errorString -match "name already exists" -or $errorString -match "already exists") {
            Write-Host "[ERROR] Repository name conflict: '$fullRepoName' already exists on GitHub." -ForegroundColor Red
            Write-Host "        Remediation: Choose a different ProjectPrefix or delete the existing repository." -ForegroundColor Yellow
            $result = [OperationResult]::new()
            $result.ResourceType = "Repository"
            $result.ResourceName = $repoName
            $result.Status = "Failed"
            $result.ErrorMessage = "Repository name conflict: '$fullRepoName' already exists."
            return $result
        }

        # Other creation failures (network, permissions, API errors)
        Write-Host "[ERROR] Repository creation failed for '$fullRepoName': $errorString" -ForegroundColor Red
        Write-Host "        Remediation: Check network connectivity, GitHub permissions, and that the project prefix is valid." -ForegroundColor Yellow
        $result = [OperationResult]::new()
        $result.ResourceType = "Repository"
        $result.ResourceName = $repoName
        $result.Status = "Failed"
        $result.ErrorMessage = "Repository creation failed: $errorString"
        return $result
    }

    # Move the cloned repo to the temp working directory
    $clonedDir = Join-Path (Get-Location).Path $repoName
    if (Test-Path $clonedDir) {
        Move-Item -Path $clonedDir -Destination (Join-Path $tempWorkDir $repoName) -Force
    }

    Write-Host "[INFO] Repository '$fullRepoName' created successfully." -ForegroundColor Green
    Write-Host "[INFO] Cloned to: $(Join-Path $tempWorkDir $repoName)" -ForegroundColor Green

    $result = [OperationResult]::new()
    $result.ResourceType = "Repository"
    $result.ResourceName = $repoName
    $result.Status = "Created"
    $result.ErrorMessage = ""
    return $result
}

# ==============================================================================
# Project Board Manager
# ==============================================================================
function New-ProjectBoard {
    <#
    .SYNOPSIS
        Creates or verifies the GitHub Projects (v2) board for the DevSecOps pipeline.
    .DESCRIPTION
        Checks if a project board named "Azure DevSecOps Pipeline Architecture" already exists
        for the specified owner. If it exists, verifies custom fields match the required
        configuration and updates if needed. If it does not exist, creates the board with
        the required description.
    .PARAMETER Owner
        The GitHub user or organization that owns the project board.
    .PARAMETER ProjectPrefix
        The project prefix used for naming context (used for logging).
    .OUTPUTS
        [OperationResult] Result object with ResourceType="ProjectBoard" and appropriate status.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$ProjectPrefix
    )

    $boardTitle = "Azure DevSecOps Pipeline Architecture"
    $boardDescription = "This project board tracks security-integrated delivery across the DevSecOps pipeline lifecycle"

    # --- DryRun Check ---
    if ($script:DryRun) {
        Write-Host "[DRY RUN] Would create project board '$boardTitle' for owner '$Owner'" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would set description: '$boardDescription'" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would create 'Phase' custom field with options: Phase 1-4" -ForegroundColor Yellow
        $result = [OperationResult]::new()
        $result.ResourceType = "ProjectBoard"
        $result.ResourceName = $boardTitle
        $result.Status = "DryRun"
        $result.ErrorMessage = ""
        return $result
    }

    $result = [OperationResult]::new()
    $result.ResourceType = "ProjectBoard"
    $result.ResourceName = $boardTitle
    $result.Status = "Failed"
    $result.ErrorMessage = ""

    try {
        # --- Check for existing board ---
        Write-Host "Checking for existing project board '$boardTitle'..." -ForegroundColor Cyan

        $projectsJson = & gh project list --owner $Owner --format json --limit 100 2>&1
        if ($LASTEXITCODE -ne 0) {
            $result.ErrorMessage = "Failed to list projects: $projectsJson"
            return $result
        }

        $projects = $projectsJson | ConvertFrom-Json
        $existingProject = $projects.projects | Where-Object { $_.title -eq $boardTitle }

        if ($existingProject) {
            # Board already exists — verify custom fields
            Write-Host "Project board '$boardTitle' already exists (number: $($existingProject.number)). Verifying configuration..." -ForegroundColor Yellow

            $projectNumber = $existingProject.number
            $needsUpdate = $false

            # Verify custom fields by listing fields on the project
            $fieldsJson = & gh project field-list $projectNumber --owner $Owner --format json 2>&1
            if ($LASTEXITCODE -ne 0) {
                $result.ErrorMessage = "Failed to list project fields: $fieldsJson"
                return $result
            }

            $fields = $fieldsJson | ConvertFrom-Json

            # Check for "Phase" custom field
            $phaseField = $fields.fields | Where-Object { $_.name -eq "Phase" }
            if (-not $phaseField) {
                Write-Host "  Missing 'Phase' custom field. Creating..." -ForegroundColor Yellow
                $createFieldOutput = & gh project field-create $projectNumber --owner $Owner --name "Phase" --data-type "SINGLE_SELECT" --single-select-options "Phase 1: Organization,Phase 2: Infrastructure,Phase 3: CI/CD,Phase 4: Delivery" 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $result.ErrorMessage = "Failed to create Phase field: $createFieldOutput"
                    return $result
                }
                $needsUpdate = $true
            } else {
                Write-Host "  'Phase' custom field exists." -ForegroundColor Green
            }

            # Check for "Status" field (built-in on v2 projects, verify it exists)
            $statusField = $fields.fields | Where-Object { $_.name -eq "Status" }
            if (-not $statusField) {
                Write-Host "  [WARN] 'Status' field not found. This is typically a built-in field on GitHub Projects v2." -ForegroundColor Yellow
                $needsUpdate = $true
            } else {
                Write-Host "  'Status' field exists." -ForegroundColor Green
            }

            if ($needsUpdate) {
                $result.Status = "Updated"
                Write-Host "Project board '$boardTitle' has been updated." -ForegroundColor Green
            } else {
                $result.Status = "AlreadyExisted"
                Write-Host "Project board '$boardTitle' configuration is correct. No changes needed." -ForegroundColor Green
            }

            # Store the project number for downstream use
            $script:ProjectBoardNumber = $projectNumber
            return $result
        }

        # --- Board does not exist — create it ---
        Write-Host "Creating project board '$boardTitle'..." -ForegroundColor Cyan

        $createOutput = & gh project create --owner $Owner --title $boardTitle 2>&1
        if ($LASTEXITCODE -ne 0) {
            $result.ErrorMessage = "Failed to create project board: $createOutput"
            return $result
        }

        # Extract the project number from the creation output (URL format: https://github.com/users/<user>/projects/<number>)
        $createOutputStr = $createOutput | Out-String
        $projectUrl = if ($createOutput -is [array]) { $createOutput[-1] } else { $createOutput }
        $projectUrl = [string]$projectUrl
        $numberMatch = if ($projectUrl) { [regex]::Match($projectUrl, "/projects/(\d+)") } else { $null }
        if ($numberMatch -and $numberMatch.Success) {
            $projectNumber = [int]$numberMatch.Groups[1].Value
        } else {
            # Also try matching from the full output string
            $fullMatch = [regex]::Match($createOutputStr, "/projects/(\d+)")
            if ($fullMatch.Success) {
                $projectNumber = [int]$fullMatch.Groups[1].Value
            } else {
                # Fallback: list projects again to find the newly created one
                $projectsJson = & gh project list --owner $Owner --format json --limit 100 2>&1
                $projects = $projectsJson | ConvertFrom-Json
                $newProject = $projects.projects | Where-Object { $_.title -eq $boardTitle }
                if ($newProject) {
                    $projectNumber = $newProject.number
                } else {
                    $result.ErrorMessage = "Project was created but could not determine project number."
                    return $result
                }
            }
        }

        Write-Host "Project board created with number: $projectNumber" -ForegroundColor Green

        # Set the project description
        Write-Host "Setting project description..." -ForegroundColor Cyan
        $editOutput = & gh project edit $projectNumber --owner $Owner --description $boardDescription 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[WARN] Failed to set project description: $editOutput" -ForegroundColor Yellow
            # Non-fatal — continue with field creation
        }

        # Create the "Phase" custom field
        Write-Host "Creating 'Phase' custom field..." -ForegroundColor Cyan
        $fieldOutput = & gh project field-create $projectNumber --owner $Owner --name "Phase" --data-type "SINGLE_SELECT" --single-select-options "Phase 1: Organization,Phase 2: Infrastructure,Phase 3: CI/CD,Phase 4: Delivery" 2>&1
        if ($LASTEXITCODE -ne 0) {
            $result.ErrorMessage = "Project created but failed to create Phase field: $fieldOutput"
            return $result
        }

        Write-Host "Project board '$boardTitle' created and configured successfully." -ForegroundColor Green

        # Store the project number for downstream use
        $script:ProjectBoardNumber = $projectNumber

        $result.Status = "Created"
        return $result

    } catch {
        $result.ErrorMessage = "Unexpected error: $($_.Exception.Message)"
        return $result
    }
}

# ==============================================================================
# Board Items Manager
# ==============================================================================
function Add-BoardItems {
    <#
    .SYNOPSIS
        Populates the GitHub Projects board with custom field verification and draft task items.
    .DESCRIPTION
        Ensures the "Phase" custom field exists with the correct options, verifies the "Status"
        field has the required values (Todo, In Progress, Done), and adds draft task items
        (one per phase) covering infrastructure provisioning, pipeline creation, and security
        integration. Each item is assigned to its corresponding Phase value.
        Uses $script:ProjectBoardNumber set by New-ProjectBoard.
    .PARAMETER Owner
        The GitHub user or organization that owns the project board.
    .OUTPUTS
        [OperationResult] Result of the board items population operation.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner
    )

    # --- DryRun Check ---
    if ($script:DryRun) {
        Write-Host "[DRY RUN] Would verify/create 'Phase' custom field on project board" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would verify 'Status' field has values: Todo, In Progress, Done" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would add 4 draft task items (one per phase) to project board" -ForegroundColor Yellow
        $result = [OperationResult]::new()
        $result.ResourceType = "BoardItems"
        $result.ResourceName = "Project Board Tasks"
        $result.Status = "DryRun"
        $result.ErrorMessage = ""
        return $result
    }

    $result = [OperationResult]::new()
    $result.ResourceType = "BoardItems"
    $result.ResourceName = "Project Board Tasks"
    $result.Status = "Failed"
    $result.ErrorMessage = ""

    # Verify that the project board number is available
    if (-not $script:ProjectBoardNumber) {
        $result.ErrorMessage = "Project board number not available. Ensure New-ProjectBoard runs first."
        return $result
    }

    $projectNumber = $script:ProjectBoardNumber

    try {
        # =====================================================================
        # Step 1: Verify/Create "Phase" Single Select field
        # =====================================================================
        Write-Host "Verifying custom fields on project board #$projectNumber..." -ForegroundColor Cyan

        $fieldsJson = & gh project field-list $projectNumber --owner $Owner --format json 2>&1
        if ($LASTEXITCODE -ne 0) {
            $result.ErrorMessage = "Failed to list project fields: $fieldsJson"
            return $result
        }

        $fields = $fieldsJson | ConvertFrom-Json
        $phaseField = $fields.fields | Where-Object { $_.name -eq "Phase" }

        if (-not $phaseField) {
            Write-Host "  Creating 'Phase' custom field..." -ForegroundColor Yellow
            $createFieldOutput = & gh project field-create $projectNumber --owner $Owner --name "Phase" --data-type "SINGLE_SELECT" --single-select-options "Phase 1: Organization,Phase 2: Infrastructure,Phase 3: CI/CD,Phase 4: Delivery" 2>&1
            if ($LASTEXITCODE -ne 0) {
                $result.ErrorMessage = "Failed to create Phase field: $createFieldOutput"
                return $result
            }
            Write-Host "  'Phase' field created successfully." -ForegroundColor Green

            # Re-fetch fields to get the Phase field ID
            $fieldsJson = & gh project field-list $projectNumber --owner $Owner --format json 2>&1
            $fields = $fieldsJson | ConvertFrom-Json
            $phaseField = $fields.fields | Where-Object { $_.name -eq "Phase" }
        } else {
            Write-Host "  'Phase' custom field already exists." -ForegroundColor Green
        }

        # =====================================================================
        # Step 2: Verify "Status" field has required values
        # =====================================================================
        $statusField = $fields.fields | Where-Object { $_.name -eq "Status" }

        if ($statusField) {
            Write-Host "  'Status' field exists. Verifying values..." -ForegroundColor Cyan

            # Status is a built-in field on GitHub Projects v2 with default values
            # The default values are "Todo", "In Progress", "Done" — verify via options if available
            $statusOptions = $statusField.options
            if ($statusOptions) {
                $requiredStatuses = @("Todo", "In Progress", "Done")
                $existingNames = $statusOptions | ForEach-Object { $_.name }
                $missingStatuses = $requiredStatuses | Where-Object { $_ -notin $existingNames }

                if ($missingStatuses.Count -gt 0) {
                    Write-Host "  [WARN] Status field is missing values: $($missingStatuses -join ', ')" -ForegroundColor Yellow
                    Write-Host "         GitHub Projects v2 Status field is managed by GitHub. Manual adjustment may be needed." -ForegroundColor Yellow
                } else {
                    Write-Host "  'Status' field has all required values: Todo, In Progress, Done." -ForegroundColor Green
                }
            } else {
                # Options not returned in field-list — Status is a built-in field with default values
                Write-Host "  'Status' field is a built-in field (default values: Todo, In Progress, Done)." -ForegroundColor Green
            }
        } else {
            Write-Host "  [WARN] 'Status' field not found. This is typically a built-in field on GitHub Projects v2." -ForegroundColor Yellow
            Write-Host "         It should be automatically available. Check the project board settings." -ForegroundColor Yellow
        }

        # =====================================================================
        # Step 3: Add draft task items (one per phase)
        # =====================================================================
        Write-Host "Adding draft task items to project board..." -ForegroundColor Cyan

        # Define the 4 task items — one per phase, covering infrastructure, pipeline, and security
        $taskItems = @(
            @{
                Title = "Set up GitHub organization, project board, and repository structure"
                Phase = "Phase 1: Organization"
            },
            @{
                Title = "Provision Azure infrastructure using Terraform modules (VNet, AKS, Key Vault)"
                Phase = "Phase 2: Infrastructure"
            },
            @{
                Title = "Create CI/CD pipelines with security scanning (SAST, SCA, container scanning)"
                Phase = "Phase 3: CI/CD"
            },
            @{
                Title = "Configure deployment workflows with monitoring and observability integration"
                Phase = "Phase 4: Delivery"
            }
        )

        $itemsCreated = 0

        foreach ($task in $taskItems) {
            Write-Host "  Adding item: '$($task.Title)'..." -ForegroundColor Cyan

            # Create draft item using gh project item-create
            $itemOutput = & gh project item-create $projectNumber --owner $Owner --title $task.Title --format json 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [WARN] Failed to create item '$($task.Title)': $itemOutput" -ForegroundColor Yellow
                continue
            }

            # Parse the item ID from the output
            $itemData = $itemOutput | ConvertFrom-Json
            $itemId = $itemData.id

            if (-not $itemId) {
                Write-Host "  [WARN] Could not determine item ID for '$($task.Title)'. Skipping field assignment." -ForegroundColor Yellow
                $itemsCreated++
                continue
            }

            # Assign the Phase field value using gh project item-edit
            if ($phaseField) {
                $phaseFieldId = $phaseField.id
                $phaseOptionId = $null

                # Find the option ID for the target phase value
                if ($phaseField.options) {
                    $targetOption = $phaseField.options | Where-Object { $_.name -eq $task.Phase }
                    if ($targetOption) {
                        $phaseOptionId = $targetOption.id
                    }
                }

                if ($phaseOptionId) {
                    $editOutput = & gh project item-edit --project-id $projectNumber --id $itemId --field-id $phaseFieldId --single-select-option-id $phaseOptionId 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "  [WARN] Failed to set Phase on item '$($task.Title)': $editOutput" -ForegroundColor Yellow
                    } else {
                        Write-Host "  Phase set to '$($task.Phase)' for item." -ForegroundColor Green
                    }
                } else {
                    # Fallback: try using the text value directly
                    $editOutput = & gh project item-edit --project-id $projectNumber --id $itemId --field-id $phaseFieldId --text $task.Phase 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "  [WARN] Could not assign Phase value for item '$($task.Title)': $editOutput" -ForegroundColor Yellow
                    }
                }
            }

            $itemsCreated++
        }

        # =====================================================================
        # Determine result status
        # =====================================================================
        if ($itemsCreated -eq $taskItems.Count) {
            Write-Host "All $itemsCreated task items added successfully." -ForegroundColor Green
            $result.Status = "Created"
        } elseif ($itemsCreated -gt 0) {
            Write-Host "$itemsCreated of $($taskItems.Count) task items added." -ForegroundColor Yellow
            $result.Status = "Created"
            $result.ErrorMessage = "Only $itemsCreated of $($taskItems.Count) items were created successfully."
        } else {
            $result.ErrorMessage = "Failed to create any task items on the project board."
            return $result
        }

        return $result

    } catch {
        $result.ErrorMessage = "Unexpected error in Add-BoardItems: $($_.Exception.Message)"
        return $result
    }
}

# ==============================================================================
# Workload Repository Creator
# ==============================================================================
function New-WorkloadRepository {
    <#
    .SYNOPSIS
        Creates the Workload repository with idempotency check.
    .DESCRIPTION
        Checks if the workload repository already exists. If it does, returns an
        OperationResult with "AlreadyExisted" status. If not, creates the repository
        as public with a description and clones it locally to a temporary working directory.
        Handles name conflicts with a specific error message and non-zero exit.
    .PARAMETER Owner
        The GitHub user or organization that owns the repository.
    .PARAMETER ProjectPrefix
        The project prefix used for naming the repository (e.g., "devsecops").
    .OUTPUTS
        [OperationResult] Result of the operation.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$ProjectPrefix
    )

    $repoName = "$ProjectPrefix-workload"

    # --- DryRun Check ---
    if ($script:DryRun) {
        Write-Host "[DRY RUN] Would create repository '$Owner/$repoName' (public)" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would clone repository to temporary working directory" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would initialize with src/, docker/, .gitignore, README.md and push to main" -ForegroundColor Yellow
        $result = [OperationResult]::new()
        $result.ResourceType = "Repository"
        $result.ResourceName = $repoName
        $result.Status = "DryRun"
        $result.ErrorMessage = ""
        return $result
    }

    # Resolve owner for gh commands (handle @me)
    if ($Owner -eq "@me") {
        $resolvedOwner = (& gh api user --jq '.login' 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $result = [OperationResult]::new()
            $result.ResourceType = "Repository"
            $result.ResourceName = $repoName
            $result.Status = "Failed"
            $result.ErrorMessage = "Unable to resolve GitHub username from '@me': $resolvedOwner"
            return $result
        }
    } else {
        $resolvedOwner = $Owner
    }

    $fullRepoName = "$resolvedOwner/$repoName"

    # --- Idempotency Check: Does the repository already exist? ---
    $viewOutput = & gh repo view $fullRepoName 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Repository already exists — skip creation
        Write-Host "[INFO] Repository '$fullRepoName' already exists. Skipping creation." -ForegroundColor Cyan
        $result = [OperationResult]::new()
        $result.ResourceType = "Repository"
        $result.ResourceName = $repoName
        $result.Status = "AlreadyExisted"
        $result.ErrorMessage = ""
        return $result
    }

    # --- Create the repository ---
    $description = "Application source code and container images for the $ProjectPrefix DevSecOps pipeline workload"

    # Create a temporary working directory for cloning
    $tempWorkDir = Join-Path ([System.IO.Path]::GetTempPath()) "devsecops-setup-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempWorkDir -Force | Out-Null

    $createOutput = & gh repo create $fullRepoName --public --description $description --clone 2>&1
    if ($LASTEXITCODE -ne 0) {
        $errorString = $createOutput | Out-String

        # Check for name conflict specifically
        if ($errorString -match "already exists" -or $errorString -match "name already exists" -or $errorString -match "Name already exists") {
            Write-Host "[ERROR] Repository creation failed for '$fullRepoName': Repository name conflict." -ForegroundColor Red
            Write-Host "        A repository with the name '$repoName' already exists under '$resolvedOwner'." -ForegroundColor Red
            Write-Host "        Remediation: Choose a different ProjectPrefix or delete the existing repository." -ForegroundColor Yellow

            # Clean up temp directory
            if (Test-Path $tempWorkDir) { Remove-Item -Path $tempWorkDir -Recurse -Force -ErrorAction SilentlyContinue }

            $result = [OperationResult]::new()
            $result.ResourceType = "Repository"
            $result.ResourceName = $repoName
            $result.Status = "Failed"
            $result.ErrorMessage = "Repository name conflict: '$fullRepoName' already exists"
            return $result
        }

        # Other creation failures (network, permissions, API errors)
        Write-Host "[ERROR] Repository creation failed for '$fullRepoName': $errorString" -ForegroundColor Red
        Write-Host "        Remediation: Check network connectivity, GitHub permissions, and API status." -ForegroundColor Yellow

        # Clean up temp directory
        if (Test-Path $tempWorkDir) { Remove-Item -Path $tempWorkDir -Recurse -Force -ErrorAction SilentlyContinue }

        $result = [OperationResult]::new()
        $result.ResourceType = "Repository"
        $result.ResourceName = $repoName
        $result.Status = "Failed"
        $result.ErrorMessage = "Repository creation failed: $errorString"
        return $result
    }

    Write-Host "[OK] Repository '$fullRepoName' created successfully." -ForegroundColor Green

    $result = [OperationResult]::new()
    $result.ResourceType = "Repository"
    $result.ResourceName = $repoName
    $result.Status = "Created"
    $result.ErrorMessage = ""
    return $result
}

# ==============================================================================
# Workload Repository File Structure Initializer
# ==============================================================================
function Initialize-WorkloadRepoFiles {
    <#
    .SYNOPSIS
        Creates the initial file structure and documentation for the Workload repository.
    .DESCRIPTION
        Populates the cloned workload repository with placeholder directories, a .gitignore
        for Node.js/Python projects, and a README documenting the repository purpose and
        target deployment platform (AKS). Commits and pushes all files to the main branch,
        then verifies main is set as the default branch.
    .PARAMETER RepoPath
        The local filesystem path to the cloned workload repository.
    .OUTPUTS
        [bool] $true if all files were created, committed, pushed, and main verified as default; $false otherwise.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Host "[ERROR] Workload repository path does not exist: $RepoPath" -ForegroundColor Red
        return $false
    }

    try {
        # --- Create directory structure ---
        $srcDir = Join-Path $RepoPath "src"
        $dockerDir = Join-Path $RepoPath "docker"

        New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
        New-Item -ItemType Directory -Path $dockerDir -Force | Out-Null

        # --- Create placeholder .gitkeep files ---
        $srcGitkeep = Join-Path $srcDir ".gitkeep"
        $dockerGitkeep = Join-Path $dockerDir ".gitkeep"

        Set-Content -Path $srcGitkeep -Value "" -NoNewline
        Set-Content -Path $dockerGitkeep -Value "" -NoNewline

        Write-Host "[INFO] Created src/.gitkeep and docker/.gitkeep" -ForegroundColor Green

        # --- Create .gitignore for Node.js/Python ---
        $gitignoreContent = @"
# Node.js
node_modules/
dist/

# Python
__pycache__/
*.pyc

# Environment
.env
"@
        $gitignorePath = Join-Path $RepoPath ".gitignore"
        Set-Content -Path $gitignorePath -Value $gitignoreContent

        Write-Host "[INFO] Created .gitignore (Node.js/Python)" -ForegroundColor Green

        # --- Create README.md ---
        $repoName = Split-Path $RepoPath -Leaf
        $readmeContent = @"
# $repoName

## Purpose

This repository contains the application source code and container images for the DevSecOps pipeline workload. It serves as the dedicated codebase for workload artifacts, managed independently from infrastructure configurations in the platform repository.

## Directory Structure

``````
$repoName/
├── src/          # Application source code
├── docker/       # Dockerfiles and container build configurations
├── .gitignore    # Ignore rules for Node.js and Python artifacts
└── README.md     # This file
``````

## Target Deployment Platform

This workload is designed for deployment to **Azure Kubernetes Service (AKS)**, provisioned and managed by the platform infrastructure repository. The CI/CD pipeline (Phase 3) will build container images from the ``docker/`` directory and deploy them to the AKS cluster.

## Getting Started

1. Clone this repository
2. Add application source code under ``src/``
3. Add Dockerfiles under ``docker/``
4. Push changes to trigger the CI/CD pipeline (configured in Phase 3)
"@
        $readmePath = Join-Path $RepoPath "README.md"
        Set-Content -Path $readmePath -Value $readmeContent

        Write-Host "[INFO] Created README.md" -ForegroundColor Green

        # --- Commit and push to main ---
        Push-Location $RepoPath
        try {
            # Stage all files
            & git add -A 2>&1 | Out-Null

            # Ensure we are on 'main' branch before committing
            $currentBranch = & git rev-parse --abbrev-ref HEAD 2>&1
            if ($currentBranch -ne "main") {
                Write-Host "[INFO] Current branch is '$currentBranch'. Renaming to 'main'..." -ForegroundColor Yellow
                & git branch -M main 2>&1 | Out-Null
            }

            # Commit with descriptive message
            $commitOutput = & git commit -m "Initialize workload repository structure" -m "Add src/ and docker/ directories with .gitkeep placeholders, .gitignore for Node.js/Python projects, and README with repository documentation." 2>&1
            if ($LASTEXITCODE -ne 0) {
                $commitStr = $commitOutput | Out-String
                # If nothing to commit, files may already exist
                if ($commitStr -match "nothing to commit") {
                    Write-Host "[INFO] No new changes to commit — files already exist." -ForegroundColor Yellow
                } else {
                    Write-Host "[ERROR] Git commit failed: $commitStr" -ForegroundColor Red
                    return $false
                }
            } else {
                Write-Host "[INFO] Committed workload repository files." -ForegroundColor Green
            }

            # Push to main
            $pushOutput = & git push -u origin main 2>&1
            if ($LASTEXITCODE -ne 0) {
                $pushStr = $pushOutput | Out-String
                # Check if it's just "everything up-to-date"
                if ($pushStr -match "up-to-date" -or $pushStr -match "Everything up-to-date") {
                    Write-Host "[INFO] Remote is already up-to-date." -ForegroundColor Yellow
                } else {
                    Write-Host "[ERROR] Git push failed: $pushStr" -ForegroundColor Red
                    return $false
                }
            } else {
                Write-Host "[INFO] Pushed workload repository files to main." -ForegroundColor Green
            }

            # --- Verify main is the default branch ---
            $currentBranch = & git rev-parse --abbrev-ref HEAD 2>&1
            if ($currentBranch -ne "main") {
                Write-Host "[WARN] Current branch is '$currentBranch', expected 'main'." -ForegroundColor Yellow
                # Attempt to rename branch to main
                & git branch -M main 2>&1 | Out-Null
                & git push -u origin main 2>&1 | Out-Null
            }

            # Verify default branch on remote via gh CLI
            $repoFullName = & git remote get-url origin 2>&1
            if ($repoFullName -match "github\.com[:/](.+?)(?:\.git)?$") {
                $remoteRepo = $Matches[1]
                $defaultBranch = & gh repo view $remoteRepo --json defaultBranchRef --jq ".defaultBranchRef.name" 2>&1
                if ($defaultBranch -eq "main") {
                    Write-Host "[INFO] Verified 'main' is the default branch." -ForegroundColor Green
                } else {
                    Write-Host "[WARN] Default branch is '$defaultBranch'. Attempting to set 'main' as default..." -ForegroundColor Yellow
                    & gh repo edit $remoteRepo --default-branch main 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[INFO] Set 'main' as the default branch." -ForegroundColor Green
                    } else {
                        Write-Host "[WARN] Could not set 'main' as default branch. Please set it manually." -ForegroundColor Yellow
                    }
                }
            }

            Write-Host "[OK] Workload repository file structure initialized successfully." -ForegroundColor Green
            return $true

        } finally {
            Pop-Location
        }

    } catch {
        Write-Host "[ERROR] Failed to initialize workload repository files: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ==============================================================================
# Platform Repository File Initializer
# ==============================================================================
function Initialize-PlatformRepoFiles {
    <#
    .SYNOPSIS
        Creates the Platform Repository directory structure and root module files.
    .DESCRIPTION
        Generates all Terraform configuration files for the platform repository including:
        - Root-level main.tf (configuration router consuming child modules)
        - Root-level variables.tf (all variable declarations)
        - Root-level outputs.tf (key outputs from child modules)
        - Root-level providers.tf (azurerm provider with backend block, key omitted)
        - environments/project-alpha-dev.tfvars (example environment file)
        - terraform.tfvars.example (documented variable template)
        - .gitignore for Terraform

        All Terraform files contain zero hardcoded values — every name, SKU, region,
        and address space is exposed as a variable.
    .PARAMETER RepoPath
        The path to the cloned platform repository directory.
    .OUTPUTS
        None. Creates files on disk.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Host "[ERROR] Repository path does not exist: $RepoPath" -ForegroundColor Red
        return
    }

    # --- Create directories ---
    $environmentsDir = Join-Path $RepoPath "environments"
    New-Item -ItemType Directory -Path $environmentsDir -Force | Out-Null

    # --- Root main.tf: Configuration router consuming child modules ---
    $mainTf = @'
# ==============================================================================
# Root Module — Configuration Router
# ==============================================================================
# This file consumes child modules and maps variables from .tfvars files to
# module inputs. It contains no resource definitions itself.
# ==============================================================================

module "network" {
  source = "./modules/network"

  resource_group_name = var.resource_group_name
  location            = var.location
  environment         = var.environment
  project_prefix      = var.project_prefix
  vnet_name           = var.vnet_name
  vnet_address_space  = var.vnet_address_space
  subnet_configs      = var.subnet_configs
  tags                = var.tags
}

module "aks" {
  source = "./modules/aks"

  resource_group_name    = var.resource_group_name
  location               = var.location
  environment            = var.environment
  project_prefix         = var.project_prefix
  cluster_name           = var.aks_cluster_name
  dns_prefix             = var.aks_dns_prefix
  kubernetes_version     = var.kubernetes_version
  node_pool_name         = var.aks_node_pool_name
  node_count             = var.aks_node_count
  node_vm_size           = var.aks_node_vm_size
  node_os_disk_size_gb   = var.aks_node_os_disk_size_gb
  max_pods_per_node      = var.aks_max_pods_per_node
  network_plugin         = var.aks_network_plugin
  subnet_id              = module.network.subnet_ids["aks"]
  tags                   = var.tags

  depends_on = [module.network]
}

module "security" {
  source = "./modules/security"

  resource_group_name    = var.resource_group_name
  location               = var.location
  environment            = var.environment
  project_prefix         = var.project_prefix
  key_vault_name         = var.key_vault_name
  key_vault_sku          = var.key_vault_sku
  log_analytics_name     = var.log_analytics_workspace_name
  log_analytics_sku      = var.log_analytics_sku
  log_retention_days     = var.log_retention_days
  tags                   = var.tags

  depends_on = [module.network]
}
'@

    # --- Root variables.tf: All variable declarations ---
    $variablesTf = @'
# ==============================================================================
# Root Module — Variable Declarations
# ==============================================================================
# All values are injected via .tfvars files. No defaults contain environment-
# specific values. This ensures the same codebase supports multiple environments.
# ==============================================================================

# --- General / Shared ---

variable "project_prefix" {
  description = "Prefix used for naming all resources (e.g., devsecops)"
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (e.g., dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for all resources (e.g., eastus, westeurope)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group to deploy into"
  type        = string
}

variable "tags" {
  description = "Map of tags applied to all resources for cost tracking and organization"
  type        = map(string)
  default     = {}
}

# --- Network Module ---

variable "vnet_name" {
  description = "Name of the Azure Virtual Network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space CIDR blocks for the virtual network (e.g., [\"10.0.0.0/16\"])"
  type        = list(string)
}

variable "subnet_configs" {
  description = "Map of subnet configurations with name as key and CIDR prefixes as value"
  type = map(object({
    address_prefixes = list(string)
  }))
}

# --- AKS Module ---

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "aks_dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster (e.g., 1.28)"
  type        = string
}

variable "aks_node_pool_name" {
  description = "Name of the default node pool"
  type        = string
}

variable "aks_node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
}

variable "aks_node_vm_size" {
  description = "VM size SKU for AKS nodes (e.g., Standard_DS2_v2)"
  type        = string
}

variable "aks_node_os_disk_size_gb" {
  description = "OS disk size in GB for each AKS node"
  type        = number
}

variable "aks_max_pods_per_node" {
  description = "Maximum number of pods per AKS node"
  type        = number
}

variable "aks_network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
}

# --- Security Module ---

variable "key_vault_name" {
  description = "Name of the Azure Key Vault for secrets management"
  type        = string
}

variable "key_vault_sku" {
  description = "SKU tier for Key Vault (standard or premium)"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace for monitoring"
  type        = string
}

variable "log_analytics_sku" {
  description = "SKU for the Log Analytics workspace (e.g., PerGB2018)"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
}
'@

    # --- Root outputs.tf: Key outputs from child modules ---
    $outputsTf = @'
# ==============================================================================
# Root Module — Outputs
# ==============================================================================
# Exposes key outputs from child modules for use by other systems, pipelines,
# or downstream Terraform configurations.
# ==============================================================================

# --- Network Outputs ---

output "vnet_id" {
  description = "The ID of the provisioned virtual network"
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "The name of the provisioned virtual network"
  value       = module.network.vnet_name
}

output "subnet_ids" {
  description = "Map of subnet names to their resource IDs"
  value       = module.network.subnet_ids
}

# --- AKS Outputs ---

output "aks_cluster_id" {
  description = "The ID of the AKS cluster"
  value       = module.aks.cluster_id
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_kube_config" {
  description = "Kubeconfig for connecting to the AKS cluster"
  value       = module.aks.kube_config
  sensitive   = true
}

output "aks_cluster_fqdn" {
  description = "The FQDN of the AKS cluster"
  value       = module.aks.cluster_fqdn
}

# --- Security Outputs ---

output "key_vault_id" {
  description = "The ID of the Key Vault"
  value       = module.security.key_vault_id
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = module.security.key_vault_uri
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = module.security.log_analytics_workspace_id
}
'@

    # --- Root providers.tf: azurerm provider with backend block (key omitted) ---
    $providersTf = @'
# ==============================================================================
# Provider Configuration
# ==============================================================================
# The backend "key" is intentionally omitted here. It is injected dynamically
# at pipeline execution time via:
#   terraform init -backend-config="key=<environment>.terraform.tfstate"
#
# This enables state isolation — each environment gets its own state file
# without modifying any Terraform source code.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    # key is omitted — injected at runtime via -backend-config
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}
'@

    # --- environments/project-alpha-dev.tfvars ---
    $envTfvars = @'
# ==============================================================================
# Environment: project-alpha-dev
# ==============================================================================
# This file declares all variables required by the root module for the
# "project-alpha" project in the "dev" environment.
# ==============================================================================

# --- General / Shared ---
project_prefix      = "projectalpha"
environment         = "dev"
location            = "eastus"
resource_group_name = "rg-projectalpha-dev"

tags = {
  Environment = "dev"
  Project     = "project-alpha"
  ManagedBy   = "terraform"
  Phase       = "2-infrastructure"
}

# --- Network ---
vnet_name          = "vnet-projectalpha-dev"
vnet_address_space = ["10.0.0.0/16"]

subnet_configs = {
  aks = {
    address_prefixes = ["10.0.1.0/24"]
  }
  appgw = {
    address_prefixes = ["10.0.2.0/24"]
  }
  data = {
    address_prefixes = ["10.0.3.0/24"]
  }
}

# --- AKS ---
aks_cluster_name         = "aks-projectalpha-dev"
aks_dns_prefix           = "projectalpha-dev"
kubernetes_version       = "1.28"
aks_node_pool_name       = "default"
aks_node_count           = 2
aks_node_vm_size         = "Standard_DS2_v2"
aks_node_os_disk_size_gb = 30
aks_max_pods_per_node    = 30
aks_network_plugin       = "azure"

# --- Security ---
key_vault_name               = "kv-projectalpha-dev"
key_vault_sku                = "standard"
log_analytics_workspace_name = "law-projectalpha-dev"
log_analytics_sku            = "PerGB2018"
log_retention_days           = 30
'@

    # --- terraform.tfvars.example ---
    $tfvarsExample = @'
# ==============================================================================
# terraform.tfvars.example
# ==============================================================================
# Template for creating environment-specific variable files.
#
# USAGE:
#   1. Copy this file: cp terraform.tfvars.example environments/<env-name>.tfvars
#   2. Replace all placeholder values with your environment-specific values
#   3. Run: terraform apply -var-file="environments/<env-name>.tfvars"
#
# Every variable is documented with its purpose, valid values, and a sample.
# ==============================================================================

# --- General / Shared ---

# Purpose: Prefix used for naming all resources to avoid conflicts
# Valid values: 3-15 lowercase alphanumeric characters, no hyphens
# Sample: "devsecops"
project_prefix = "myproject"

# Purpose: Deployment environment identifier for resource tagging and naming
# Valid values: "dev", "staging", "prod"
# Sample: "dev"
environment = "dev"

# Purpose: Azure region where all resources will be deployed
# Valid values: Any valid Azure region (e.g., "eastus", "westeurope", "southeastasia")
# Sample: "eastus"
location = "eastus"

# Purpose: Name of the Azure resource group to contain all resources
# Valid values: 1-90 characters, alphanumeric, hyphens, underscores, periods, parentheses
# Sample: "rg-devsecops-dev"
resource_group_name = "rg-myproject-dev"

# Purpose: Map of tags applied to all resources for cost tracking and organization
# Valid values: Key-value pairs of strings
# Sample: { Environment = "dev", Project = "my-project", ManagedBy = "terraform" }
tags = {
  Environment = "dev"
  Project     = "my-project"
  ManagedBy   = "terraform"
  Phase       = "2-infrastructure"
}

# --- Network Module ---

# Purpose: Name of the Azure Virtual Network
# Valid values: 2-64 characters, alphanumeric, hyphens, underscores, periods
# Sample: "vnet-devsecops-dev"
vnet_name = "vnet-myproject-dev"

# Purpose: Address space CIDR blocks for the virtual network
# Valid values: List of valid CIDR notation strings (e.g., ["10.0.0.0/16"])
# Sample: ["10.0.0.0/16"]
vnet_address_space = ["10.0.0.0/16"]

# Purpose: Map of subnet configurations with name as key and CIDR prefixes as value
# Valid values: Map of objects with address_prefixes list; subnets must be within vnet CIDR
# Sample: { aks = { address_prefixes = ["10.0.1.0/24"] } }
subnet_configs = {
  aks = {
    address_prefixes = ["10.0.1.0/24"]
  }
  appgw = {
    address_prefixes = ["10.0.2.0/24"]
  }
  data = {
    address_prefixes = ["10.0.3.0/24"]
  }
}

# --- AKS Module ---

# Purpose: Name of the AKS managed Kubernetes cluster
# Valid values: 1-63 characters, alphanumeric and hyphens
# Sample: "aks-devsecops-dev"
aks_cluster_name = "aks-myproject-dev"

# Purpose: DNS prefix for the AKS cluster API server
# Valid values: 1-54 characters, alphanumeric and hyphens, must start with letter
# Sample: "devsecops-dev"
aks_dns_prefix = "myproject-dev"

# Purpose: Kubernetes version for the AKS cluster
# Valid values: Supported AKS versions (e.g., "1.27", "1.28", "1.29")
# Sample: "1.28"
kubernetes_version = "1.28"

# Purpose: Name of the default node pool
# Valid values: 1-12 lowercase alphanumeric characters
# Sample: "default"
aks_node_pool_name = "default"

# Purpose: Number of nodes in the default node pool
# Valid values: 1-1000 (use 1-3 for dev, 3+ for prod)
# Sample: 2
aks_node_count = 2

# Purpose: VM size SKU for AKS nodes
# Valid values: Any valid Azure VM size (e.g., "Standard_DS2_v2", "Standard_B2s")
# Sample: "Standard_DS2_v2"
aks_node_vm_size = "Standard_DS2_v2"

# Purpose: OS disk size in GB for each AKS node
# Valid values: 30-2048 (minimum 30 GB recommended)
# Sample: 30
aks_node_os_disk_size_gb = 30

# Purpose: Maximum number of pods per AKS node
# Valid values: 10-250 (30 is default for Azure CNI)
# Sample: 30
aks_max_pods_per_node = 30

# Purpose: Network plugin for AKS networking
# Valid values: "azure" (Azure CNI) or "kubenet"
# Sample: "azure"
aks_network_plugin = "azure"

# --- Security Module ---

# Purpose: Name of the Azure Key Vault for secrets management
# Valid values: 3-24 characters, alphanumeric and hyphens, globally unique
# Sample: "kv-devsecops-dev"
key_vault_name = "kv-myproject-dev"

# Purpose: SKU tier for Key Vault
# Valid values: "standard" or "premium" (premium adds HSM-backed keys)
# Sample: "standard"
key_vault_sku = "standard"

# Purpose: Name of the Log Analytics workspace for monitoring and security logs
# Valid values: 4-63 characters, alphanumeric and hyphens
# Sample: "law-devsecops-dev"
log_analytics_workspace_name = "law-myproject-dev"

# Purpose: SKU for the Log Analytics workspace
# Valid values: "PerGB2018", "Free", "Standalone", "PerNode"
# Sample: "PerGB2018"
log_analytics_sku = "PerGB2018"

# Purpose: Number of days to retain logs in Log Analytics
# Valid values: 30-730 (30 for dev, 90+ for prod)
# Sample: 30
log_retention_days = 30
'@

    # --- .gitignore for Terraform ---
    $gitignore = @'
# ==============================================================================
# Terraform .gitignore
# ==============================================================================

# Local .terraform directories
.terraform/

# Terraform state files (contain sensitive data)
*.tfstate
*.tfstate.backup

# Terraform lock file (regenerated on init)
.terraform.lock.hcl

# Sensitive variable files (may contain secrets)
*.tfvars
!terraform.tfvars.example
!environments/*.tfvars

# Crash log files
crash.log
crash.*.log

# Override files (local developer overrides)
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# CLI configuration files
.terraformrc
terraform.rc
'@

    # --- Write all files ---
    Write-Host "[INFO] Creating Platform Repository file structure at: $RepoPath" -ForegroundColor Cyan

    Set-Content -Path (Join-Path $RepoPath "main.tf") -Value $mainTf -Encoding UTF8
    Write-Host "  Created: main.tf" -ForegroundColor Green

    Set-Content -Path (Join-Path $RepoPath "variables.tf") -Value $variablesTf -Encoding UTF8
    Write-Host "  Created: variables.tf" -ForegroundColor Green

    Set-Content -Path (Join-Path $RepoPath "outputs.tf") -Value $outputsTf -Encoding UTF8
    Write-Host "  Created: outputs.tf" -ForegroundColor Green

    Set-Content -Path (Join-Path $RepoPath "providers.tf") -Value $providersTf -Encoding UTF8
    Write-Host "  Created: providers.tf" -ForegroundColor Green

    Set-Content -Path (Join-Path $environmentsDir "project-alpha-dev.tfvars") -Value $envTfvars -Encoding UTF8
    Write-Host "  Created: environments/project-alpha-dev.tfvars" -ForegroundColor Green

    Set-Content -Path (Join-Path $RepoPath "terraform.tfvars.example") -Value $tfvarsExample -Encoding UTF8
    Write-Host "  Created: terraform.tfvars.example" -ForegroundColor Green

    Set-Content -Path (Join-Path $RepoPath ".gitignore") -Value $gitignore -Encoding UTF8
    Write-Host "  Created: .gitignore" -ForegroundColor Green

    Write-Host "[OK] Platform Repository file structure created successfully." -ForegroundColor Green
}

# ==============================================================================
# Platform Repository Child Modules Initializer
# ==============================================================================
function Initialize-PlatformModules {
    <#
    .SYNOPSIS
        Creates the Platform Repository child modules (network, aks, security).
    .DESCRIPTION
        Generates the child module directories and Terraform files for:
        - modules/network/ — Azure VNet and subnet resources
        - modules/aks/ — AKS cluster resource
        - modules/security/ — Key Vault and Log Analytics workspace resources

        All modules contain zero hardcoded values. Every name, SKU, region, and
        address space is exposed as a variable. The root main.tf (created in Task 3.2)
        maps variables from .tfvars to module inputs.
    .PARAMETER RepoPath
        The path to the cloned platform repository directory.
    .OUTPUTS
        None. Creates module directories and files on disk.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Host "[ERROR] Repository path does not exist: $RepoPath" -ForegroundColor Red
        return
    }

    Write-Host "[INFO] Creating Platform Repository child modules at: $RepoPath" -ForegroundColor Cyan

    # ==========================================================================
    # modules/network/
    # ==========================================================================
    $networkDir = Join-Path (Join-Path $RepoPath "modules") "network"
    New-Item -ItemType Directory -Path $networkDir -Force | Out-Null

    # --- modules/network/main.tf ---
    $networkMain = @'
# ==============================================================================
# Network Module — Azure VNet and Subnets
# ==============================================================================
# Provisions an Azure Virtual Network with configurable subnets.
# All values are parameterized — no hardcoded names, CIDRs, or regions.
# ==============================================================================

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  tags = merge(var.tags, {
    Module      = "network"
    Environment = var.environment
  })
}

resource "azurerm_subnet" "this" {
  for_each = var.subnet_configs

  name                 = "${var.project_prefix}-${each.key}-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes
}
'@

    # --- modules/network/variables.tf ---
    $networkVariables = @'
# ==============================================================================
# Network Module — Variables
# ==============================================================================

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the virtual network"
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (e.g., dev, staging, prod)"
  type        = string
}

variable "project_prefix" {
  description = "Prefix used for naming subnet resources"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Azure Virtual Network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space CIDR blocks for the virtual network"
  type        = list(string)
}

variable "subnet_configs" {
  description = "Map of subnet configurations with name as key and address prefixes as value"
  type = map(object({
    address_prefixes = list(string)
  }))
}

variable "tags" {
  description = "Map of tags applied to network resources"
  type        = map(string)
  default     = {}
}
'@

    # --- modules/network/outputs.tf ---
    $networkOutputs = @'
# ==============================================================================
# Network Module — Outputs
# ==============================================================================

output "vnet_id" {
  description = "The resource ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map of subnet names to their resource IDs"
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}
'@

    Set-Content -Path (Join-Path $networkDir "main.tf") -Value $networkMain -Encoding UTF8
    Set-Content -Path (Join-Path $networkDir "variables.tf") -Value $networkVariables -Encoding UTF8
    Set-Content -Path (Join-Path $networkDir "outputs.tf") -Value $networkOutputs -Encoding UTF8
    Write-Host "  Created: modules/network/ (main.tf, variables.tf, outputs.tf)" -ForegroundColor Green

    # ==========================================================================
    # modules/aks/
    # ==========================================================================
    $aksDir = Join-Path (Join-Path $RepoPath "modules") "aks"
    New-Item -ItemType Directory -Path $aksDir -Force | Out-Null

    # --- modules/aks/main.tf ---
    $aksMain = @'
# ==============================================================================
# AKS Module — Azure Kubernetes Service Cluster
# ==============================================================================
# Provisions an AKS cluster with a configurable default node pool.
# All values are parameterized — no hardcoded names, SKUs, or versions.
# ==============================================================================

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = var.node_pool_name
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    os_disk_size_gb     = var.node_os_disk_size_gb
    max_pods            = var.max_pods_per_node
    vnet_subnet_id      = var.subnet_id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = var.network_plugin
  }

  tags = merge(var.tags, {
    Module      = "aks"
    Environment = var.environment
  })
}
'@

    # --- modules/aks/variables.tf ---
    $aksVariables = @'
# ==============================================================================
# AKS Module — Variables
# ==============================================================================

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the AKS cluster"
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (e.g., dev, staging, prod)"
  type        = string
}

variable "project_prefix" {
  description = "Prefix used for naming resources"
  type        = string
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster API server"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the default node pool"
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
}

variable "node_vm_size" {
  description = "VM size SKU for AKS nodes"
  type        = string
}

variable "node_os_disk_size_gb" {
  description = "OS disk size in GB for each AKS node"
  type        = number
}

variable "max_pods_per_node" {
  description = "Maximum number of pods per AKS node"
  type        = number
}

variable "network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the subnet for the AKS node pool"
  type        = string
}

variable "tags" {
  description = "Map of tags applied to AKS resources"
  type        = map(string)
  default     = {}
}
'@

    # --- modules/aks/outputs.tf ---
    $aksOutputs = @'
# ==============================================================================
# AKS Module — Outputs
# ==============================================================================

output "cluster_id" {
  description = "The resource ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.name
}

output "kube_config" {
  description = "Kubeconfig for connecting to the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "cluster_fqdn" {
  description = "The FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.fqdn
}
'@

    Set-Content -Path (Join-Path $aksDir "main.tf") -Value $aksMain -Encoding UTF8
    Set-Content -Path (Join-Path $aksDir "variables.tf") -Value $aksVariables -Encoding UTF8
    Set-Content -Path (Join-Path $aksDir "outputs.tf") -Value $aksOutputs -Encoding UTF8
    Write-Host "  Created: modules/aks/ (main.tf, variables.tf, outputs.tf)" -ForegroundColor Green

    # ==========================================================================
    # modules/security/
    # ==========================================================================
    $securityDir = Join-Path (Join-Path $RepoPath "modules") "security"
    New-Item -ItemType Directory -Path $securityDir -Force | Out-Null

    # --- modules/security/main.tf ---
    $securityMain = @'
# ==============================================================================
# Security Module — Key Vault and Log Analytics Workspace
# ==============================================================================
# Provisions Azure Key Vault for secrets management and a Log Analytics
# workspace for centralized logging and monitoring.
# All values are parameterized — no hardcoded names, SKUs, or retention periods.
# ==============================================================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = var.key_vault_sku
  purge_protection_enabled    = true
  soft_delete_retention_days  = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
    ]

    key_permissions = [
      "Get",
      "List",
      "Create",
      "Delete",
      "Purge",
    ]
  }

  tags = merge(var.tags, {
    Module      = "security"
    Environment = var.environment
  })
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_retention_days

  tags = merge(var.tags, {
    Module      = "security"
    Environment = var.environment
  })
}
'@

    # --- modules/security/variables.tf ---
    $securityVariables = @'
# ==============================================================================
# Security Module — Variables
# ==============================================================================

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region for security resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (e.g., dev, staging, prod)"
  type        = string
}

variable "project_prefix" {
  description = "Prefix used for naming resources"
  type        = string
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault"
  type        = string
}

variable "key_vault_sku" {
  description = "SKU tier for Key Vault (standard or premium)"
  type        = string
}

variable "log_analytics_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "log_analytics_sku" {
  description = "SKU for the Log Analytics workspace"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
}

variable "tags" {
  description = "Map of tags applied to security resources"
  type        = map(string)
  default     = {}
}
'@

    # --- modules/security/outputs.tf ---
    $securityOutputs = @'
# ==============================================================================
# Security Module — Outputs
# ==============================================================================

output "key_vault_id" {
  description = "The resource ID of the Key Vault"
  value       = azurerm_key_vault.this.id
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = azurerm_key_vault.this.vault_uri
}

output "log_analytics_workspace_id" {
  description = "The resource ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.this.id
}
'@

    Set-Content -Path (Join-Path $securityDir "main.tf") -Value $securityMain -Encoding UTF8
    Set-Content -Path (Join-Path $securityDir "variables.tf") -Value $securityVariables -Encoding UTF8
    Set-Content -Path (Join-Path $securityDir "outputs.tf") -Value $securityOutputs -Encoding UTF8
    Write-Host "  Created: modules/security/ (main.tf, variables.tf, outputs.tf)" -ForegroundColor Green

    Write-Host "[OK] Platform Repository child modules created successfully." -ForegroundColor Green
}

# ==============================================================================
# Platform Repository Pipeline Initializer
# ==============================================================================
function Initialize-PlatformPipeline {
    <#
    .SYNOPSIS
        Creates the GitHub Actions workflow file for Terraform deployment in the Platform Repository.
    .DESCRIPTION
        Generates the .github/workflows/terraform-deploy.yml pipeline file that demonstrates:
        - Trigger definitions (push to main, pull_request, workflow_dispatch with environment input)
        - Dynamic state key injection via terraform init -backend-config
        - Variable file selection via terraform apply -var-file
        - Standard Terraform workflow steps (checkout, setup-terraform, init, validate, plan, apply)
        - Azure login using OIDC or service principal credentials from secrets

        This pipeline enables environment isolation by injecting the state key and variable
        file dynamically based on the selected environment input.
    .PARAMETER RepoPath
        The local filesystem path to the cloned platform repository.
    .OUTPUTS
        None. Creates the .github/workflows/terraform-deploy.yml file on disk.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Host "[ERROR] Platform repository path does not exist: $RepoPath" -ForegroundColor Red
        return
    }

    # --- Create .github/workflows directory ---
    $workflowsDir = Join-Path (Join-Path $RepoPath ".github") "workflows"
    New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null

    # --- terraform-deploy.yml content ---
    $workflowYaml = @'
# ==============================================================================
# Terraform Deploy Pipeline
# ==============================================================================
# This workflow demonstrates dynamic state key injection and variable file
# selection for environment isolation. Each environment gets its own state file
# and variable configuration without modifying any Terraform source code.
#
# Trigger: push to main, pull requests, or manual dispatch with environment input.
# ==============================================================================

name: Terraform Deploy

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment (e.g., project-alpha-dev, project-beta-prod)"
        required: true
        default: "project-alpha-dev"
        type: string

permissions:
  id-token: write
  contents: read

env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  TF_VERSION: "1.5.0"

jobs:
  terraform:
    name: "Terraform ${{ inputs.environment || 'project-alpha-dev' }}"
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'project-alpha-dev' }}

    steps:
      # -----------------------------------------------------------------------
      # Step 1: Checkout repository
      # -----------------------------------------------------------------------
      - name: Checkout code
        uses: actions/checkout@v4

      # -----------------------------------------------------------------------
      # Step 2: Azure Login using OIDC (federated credentials)
      # -----------------------------------------------------------------------
      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      # -----------------------------------------------------------------------
      # Step 3: Setup Terraform
      # -----------------------------------------------------------------------
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      # -----------------------------------------------------------------------
      # Step 4: Terraform Init with dynamic state key injection
      # -----------------------------------------------------------------------
      # The state key is derived from the environment input, enabling each
      # environment to maintain its own isolated state file in the backend.
      - name: Terraform Init
        run: |
          terraform init -backend-config="key=${{ inputs.environment }}.terraform.tfstate"

      # -----------------------------------------------------------------------
      # Step 5: Terraform Validate
      # -----------------------------------------------------------------------
      - name: Terraform Validate
        run: terraform validate

      # -----------------------------------------------------------------------
      # Step 6: Terraform Plan with environment-specific variable file
      # -----------------------------------------------------------------------
      # The variable file is selected based on the environment input, allowing
      # the same Terraform code to produce different infrastructure per environment.
      - name: Terraform Plan
        run: |
          terraform plan \
            -var-file="environments/${{ inputs.environment }}.tfvars" \
            -out=tfplan \
            -input=false

      # -----------------------------------------------------------------------
      # Step 7: Terraform Apply (only on push to main or manual dispatch)
      # -----------------------------------------------------------------------
      - name: Terraform Apply
        if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
        run: |
          terraform apply \
            -var-file="environments/${{ inputs.environment }}.tfvars" \
            -auto-approve \
            -input=false
'@

    # --- Write the workflow file ---
    $workflowPath = Join-Path $workflowsDir "terraform-deploy.yml"
    Set-Content -Path $workflowPath -Value $workflowYaml -Encoding UTF8

    Write-Host "[INFO] Creating Platform Repository pipeline at: $workflowPath" -ForegroundColor Cyan
    Write-Host "  Created: .github/workflows/terraform-deploy.yml" -ForegroundColor Green
    Write-Host "[OK] Platform Repository pipeline created successfully." -ForegroundColor Green
}

# ==============================================================================
# Platform Repository README Documentation
# ==============================================================================
function Initialize-PlatformReadme {
    <#
    .SYNOPSIS
        Creates the README.md documentation for the Platform Repository.
    .DESCRIPTION
        Generates a comprehensive README.md that explains the platform repository's role
        as a reusable infrastructure-as-code store supporting multiple DevSecOps environments.
        Includes sections on reusable module architecture, step-by-step environment addition,
        dynamic state key injection for environment isolation, directory structure overview,
        and prerequisites.
    .PARAMETER RepoPath
        The local filesystem path to the cloned platform repository.
    .OUTPUTS
        None. Creates README.md on disk.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Host "[ERROR] Repository path does not exist: $RepoPath" -ForegroundColor Red
        return
    }

    $repoName = Split-Path $RepoPath -Leaf

    $readmeContent = @"
# $repoName

## Overview

This repository serves as the **reusable infrastructure-as-code store** for the Azure DevSecOps Pipeline Architecture. It contains modular Terraform configurations designed so that a new, fully isolated DevSecOps environment can be provisioned by adding a single ``.tfvars`` file and running the pipeline — no modifications to module source code, root configuration, or pipeline definitions are required.

The platform repository supports multiple DevSecOps environments (dev, staging, production) from a single codebase, demonstrating enterprise-grade modularity and the separation of configuration from code.

## Reusable Module Architecture

The repository follows a **root module + child modules** pattern where the root ``main.tf`` acts as a configuration router, consuming child modules and mapping variables from environment-specific ``.tfvars`` files to module inputs.

### Child Modules

| Module | Path | Purpose |
|--------|------|---------|
| **Network** | ``modules/network/`` | Provisions Azure Virtual Network, subnets, and network security groups. All CIDR ranges, names, and configurations are parameterized. |
| **AKS** | ``modules/aks/`` | Provisions Azure Kubernetes Service cluster with configurable node pools, networking, and Kubernetes version. |
| **Security** | ``modules/security/`` | Provisions Azure Key Vault for secrets management and Log Analytics workspace for monitoring and security logging. |

Each child module:
- Contains ``main.tf``, ``variables.tf``, and ``outputs.tf``
- Exposes **zero hardcoded values** — every name, SKU, region, and address space is a variable
- Can be consumed independently or composed together via the root module
- Outputs resource IDs and connection details for cross-module references

## Adding a New Environment

Follow these steps to provision a new, fully isolated DevSecOps environment:

1. **Create a new ``.tfvars`` file** — Copy ``terraform.tfvars.example`` to ``environments/<your-env>.tfvars`` and fill in all variable values with your environment-specific configuration (project prefix, region, resource names, SKUs, network CIDRs, etc.).

2. **Trigger the pipeline with the environment name** — Run the GitHub Actions workflow specifying your environment name. The pipeline will automatically select the correct ``.tfvars`` file from the ``environments/`` directory using ``terraform apply -var-file="environments/<your-env>.tfvars"``.

3. **Verify state isolation** — The pipeline injects a unique state key for your environment (see Dynamic State Key Injection below), ensuring your infrastructure state is completely isolated from other environments. No shared state conflicts can occur.

4. **Validate the deployment** — After the pipeline completes, verify your resources were created in the correct Azure resource group and region by checking the Terraform outputs or the Azure Portal.

## Dynamic State Key Injection

The ``providers.tf`` backend configuration intentionally **omits the ``key`` parameter**. At pipeline execution time, the CI/CD workflow injects the state key dynamically:

``````bash
terraform init -backend-config="key=<environment>.terraform.tfstate"
``````

This approach provides **environment isolation** — each environment gets its own dedicated state file in the shared Azure Storage backend without any modification to Terraform source code. For example:

- ``project-alpha-dev.terraform.tfstate``
- ``project-alpha-staging.terraform.tfstate``
- ``project-alpha-prod.terraform.tfstate``

All environments share the same storage account and container, but their state files are completely independent. This prevents resource conflicts and enables safe parallel operations across environments.

## Directory Structure

``````
$repoName/
├── main.tf                          # Configuration router — consumes child modules
├── variables.tf                     # Root-level variable declarations (all inputs)
├── outputs.tf                       # Root-level outputs from child modules
├── providers.tf                     # Provider + backend config (key omitted for dynamic injection)
├── terraform.tfvars.example         # Documented variable template for new environments
├── environments/
│   └── project-alpha-dev.tfvars     # Example environment variable file
├── modules/
│   ├── network/
│   │   ├── main.tf                  # VNet, subnets, NSGs
│   │   ├── variables.tf             # Network-specific variables
│   │   └── outputs.tf               # Network resource IDs and names
│   ├── aks/
│   │   ├── main.tf                  # AKS cluster and node pools
│   │   ├── variables.tf             # AKS-specific variables
│   │   └── outputs.tf               # Cluster ID, FQDN, kubeconfig
│   └── security/
│       ├── main.tf                  # Key Vault, Log Analytics
│       ├── variables.tf             # Security-specific variables
│       └── outputs.tf               # Vault URI, workspace ID
├── .github/
│   └── workflows/
│       └── terraform-deploy.yml     # CI/CD pipeline with dynamic state + var-file
├── .gitignore                       # Terraform-specific ignore rules
└── README.md                        # This file
``````

## Prerequisites

Before using this repository, ensure the following are in place:

- **Terraform CLI** (>= 1.5.0) installed locally or available in your CI/CD runner
- **Azure CLI** authenticated with a service principal or user account that has Contributor access to the target subscription
- **Azure Storage Account** for Terraform remote state backend (resource group: ``rg-terraform-state``, storage account: ``stterraformstate``, container: ``tfstate``)
- **GitHub Actions** configured with Azure credentials stored as repository secrets (``AZURE_CLIENT_ID``, ``AZURE_CLIENT_SECRET``, ``AZURE_SUBSCRIPTION_ID``, ``AZURE_TENANT_ID``)
- **GitHub CLI** (>= 2.21.0) for repository and project board management during Phase 1 setup

## Related Repositories

- **Workload Repository** — Contains application source code and Dockerfiles deployed to the AKS cluster provisioned by this platform repository

## License

This project is part of the Azure DevSecOps Pipeline Architecture learning portfolio.
"@

    $readmePath = Join-Path $RepoPath "README.md"
    Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8

    Write-Host "[OK] Platform Repository README.md created at: $readmePath" -ForegroundColor Green
}

# ==============================================================================
# Platform Repository Commit and Push
# ==============================================================================
function Push-PlatformRepoFiles {
    <#
    .SYNOPSIS
        Commits and pushes all Platform Repository files to the remote main branch.
    .DESCRIPTION
        Stages all files in the platform repository, commits with a descriptive message,
        pushes to the remote main branch, and verifies that main is set as the default
        branch. Handles cases where nothing to commit (files already exist) and push
        failures gracefully.
    .PARAMETER RepoPath
        The local filesystem path to the cloned platform repository.
    .OUTPUTS
        [bool] $true if all files were committed, pushed, and main verified as default; $false on failure.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Host "[ERROR] Platform repository path does not exist: $RepoPath" -ForegroundColor Red
        return $false
    }

    try {
        Push-Location $RepoPath

        # --- Stage all files ---
        Write-Host "[INFO] Staging all platform repository files..." -ForegroundColor Cyan
        $addOutput = & git add -A 2>&1
        if ($LASTEXITCODE -ne 0) {
            $addStr = $addOutput | Out-String
            Write-Host "[ERROR] Git add failed: $addStr" -ForegroundColor Red
            return $false
        }

        # --- Ensure we are on 'main' branch before committing ---
        $currentBranch = & git rev-parse --abbrev-ref HEAD 2>&1
        if ($currentBranch -ne "main") {
            Write-Host "[INFO] Current branch is '$currentBranch'. Renaming to 'main'..." -ForegroundColor Yellow
            & git branch -M main 2>&1 | Out-Null
        }

        # --- Commit with descriptive message ---
        $commitMessage = "Initialize platform infrastructure repository with Terraform modules, pipeline, and documentation"
        $commitBody = "Add root module (main.tf, variables.tf, outputs.tf, providers.tf), child modules (network, aks, security), GitHub Actions pipeline with dynamic state key injection, environment example files, and comprehensive README documentation."

        $commitOutput = & git commit -m $commitMessage -m $commitBody 2>&1
        if ($LASTEXITCODE -ne 0) {
            $commitStr = $commitOutput | Out-String
            # Handle case where nothing to commit (files already exist)
            if ($commitStr -match "nothing to commit" -or $commitStr -match "working tree clean") {
                Write-Host "[INFO] No new changes to commit — platform repository files already exist." -ForegroundColor Yellow
            } else {
                Write-Host "[ERROR] Git commit failed: $commitStr" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "[INFO] Committed platform repository files." -ForegroundColor Green
        }

        # --- Ensure we are on 'main' branch before pushing ---
        $currentBranch = & git rev-parse --abbrev-ref HEAD 2>&1
        if ($currentBranch -ne "main") {
            Write-Host "[INFO] Current branch is '$currentBranch'. Renaming to 'main'..." -ForegroundColor Yellow
            & git branch -M main 2>&1 | Out-Null
        }

        # --- Push to remote main branch ---
        Write-Host "[INFO] Pushing to remote main branch..." -ForegroundColor Cyan
        $pushOutput = & git push -u origin main 2>&1
        if ($LASTEXITCODE -ne 0) {
            $pushStr = $pushOutput | Out-String
            # Handle "everything up-to-date" (not a real failure)
            if ($pushStr -match "up-to-date" -or $pushStr -match "Everything up-to-date") {
                Write-Host "[INFO] Remote is already up-to-date." -ForegroundColor Yellow
            } else {
                Write-Host "[ERROR] Git push failed: $pushStr" -ForegroundColor Red
                Write-Host "        Remediation: Check network connectivity, remote URL, and authentication." -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host "[INFO] Pushed platform repository files to main." -ForegroundColor Green
        }

        # --- Verify main is the default branch on remote ---
        $currentBranch = & git rev-parse --abbrev-ref HEAD 2>&1
        if ($currentBranch -ne "main") {
            Write-Host "[WARN] Current branch is '$currentBranch', expected 'main'. Renaming..." -ForegroundColor Yellow
            & git branch -M main 2>&1 | Out-Null
            & git push -u origin main 2>&1 | Out-Null
        }

        # Verify default branch on remote via gh CLI
        $repoFullName = & git remote get-url origin 2>&1
        if ($repoFullName -match "github\.com[:/](.+?)(?:\.git)?$") {
            $remoteRepo = $Matches[1]
            $defaultBranch = & gh repo view $remoteRepo --json defaultBranchRef --jq ".defaultBranchRef.name" 2>&1
            if ($defaultBranch -eq "main") {
                Write-Host "[INFO] Verified 'main' is the default branch." -ForegroundColor Green
            } else {
                Write-Host "[WARN] Default branch is '$defaultBranch'. Setting 'main' as default..." -ForegroundColor Yellow
                $editOutput = & gh repo edit $remoteRepo --default-branch main 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[INFO] Set 'main' as the default branch." -ForegroundColor Green
                } else {
                    Write-Host "[WARN] Could not set 'main' as default branch: $editOutput" -ForegroundColor Yellow
                    Write-Host "       Please set it manually via: gh repo edit $remoteRepo --default-branch main" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "[WARN] Could not determine remote repository name from origin URL." -ForegroundColor Yellow
            Write-Host "       Unable to verify default branch setting." -ForegroundColor Yellow
        }

        Write-Host "[OK] Platform repository files committed and pushed to main successfully." -ForegroundColor Green
        return $true

    } catch {
        Write-Host "[ERROR] Failed to push platform repository files: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        Pop-Location
    }
}

# ==============================================================================
# Board Link Manager
# ==============================================================================
function Add-BoardLink {
    <#
    .SYNOPSIS
        Links a repository to the GitHub Projects (v2) board.
    .DESCRIPTION
        Uses the GitHub CLI to link a repository to the project board so that issues
        and pull requests from the repository appear on the board for unified tracking.
        Uses $script:ProjectBoardNumber set by New-ProjectBoard.
    .PARAMETER Owner
        The GitHub user or organization that owns the project board and repository.
    .PARAMETER RepoFullName
        The full repository name in "owner/repo-name" format (e.g., "myuser/devsecops-platform-infrastructure").
    .OUTPUTS
        [OperationResult] Result of the board link operation.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$RepoFullName
    )

    # Extract the short repo name from the full name for display purposes
    $repoShortName = $RepoFullName
    if ($RepoFullName -match "/(.+)$") {
        $repoShortName = $Matches[1]
    }

    # --- DryRun Check ---
    if ($script:DryRun) {
        Write-Host "[DRY RUN] Would link repository '$RepoFullName' to project board" -ForegroundColor Yellow
        $result = [OperationResult]::new()
        $result.ResourceType = "BoardLink"
        $result.ResourceName = $repoShortName
        $result.Status = "DryRun"
        $result.ErrorMessage = ""
        return $result
    }

    $result = [OperationResult]::new()
    $result.ResourceType = "BoardLink"
    $result.ResourceName = $repoShortName
    $result.Status = "Failed"
    $result.ErrorMessage = ""

    # Verify that the project board number is available
    if (-not $script:ProjectBoardNumber) {
        $result.ErrorMessage = "Cannot link repository '$repoShortName': Project board number not available. Ensure New-ProjectBoard runs first."
        Write-Host "[ERROR] $($result.ErrorMessage)" -ForegroundColor Red
        return $result
    }

    $projectNumber = $script:ProjectBoardNumber

    try {
        Write-Host "Linking repository '$RepoFullName' to project board #$projectNumber..." -ForegroundColor Cyan

        $linkOutput = & gh project link $projectNumber --owner $Owner --repo $RepoFullName 2>&1
        if ($LASTEXITCODE -ne 0) {
            $errorString = $linkOutput | Out-String
            $result.ErrorMessage = "Failed to link repository '$repoShortName' to project board: $errorString"
            Write-Host "[ERROR] $($result.ErrorMessage)" -ForegroundColor Red
            return $result
        }

        Write-Host "[OK] Repository '$RepoFullName' linked to project board #$projectNumber successfully." -ForegroundColor Green
        $result.Status = "Created"
        return $result

    } catch {
        $result.ErrorMessage = "Unexpected error linking repository '$repoShortName' to project board: $($_.Exception.Message)"
        Write-Host "[ERROR] $($result.ErrorMessage)" -ForegroundColor Red
        return $result
    }
}

# ==============================================================================
# Branch Protection Configurator
# ==============================================================================
function Set-BranchProtection {
    <#
    .SYNOPSIS
        Applies branch protection rules to a repository's main branch via the GitHub REST API.
    .DESCRIPTION
        Configures branch protection on the specified branch using gh api PUT request to
        repos/<owner>/<repo>/branches/<branch>/protection. Enforces:
        - Minimum 1 pull request review approval before merging
        - Enforce for administrators (no direct pushes)
        - Required status checks with placeholder context "ci/pipeline-check"

        Only executes if the target repository was created or already exists. On failure,
        logs a warning and returns a Failed OperationResult without blocking other operations.
    .PARAMETER Owner
        The GitHub user or organization that owns the repository.
    .PARAMETER RepoName
        The name of the repository (without owner prefix).
    .PARAMETER BranchName
        The branch to protect. Defaults to "main".
    .OUTPUTS
        [OperationResult] Result of the branch protection operation.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$RepoName,

        [Parameter(Mandatory = $false)]
        [string]$BranchName = "main"
    )

    # --- DryRun Check ---
    if ($script:DryRun) {
        Write-Host "[DRY RUN] Would apply branch protection to '$Owner/$RepoName' branch '$BranchName'" -ForegroundColor Yellow
        Write-Host "[DRY RUN]   - Required reviewers: 1" -ForegroundColor Yellow
        Write-Host "[DRY RUN]   - Enforce for admins: Yes (no direct pushes)" -ForegroundColor Yellow
        Write-Host "[DRY RUN]   - Required status checks: ci/pipeline-check" -ForegroundColor Yellow
        $result = [OperationResult]::new()
        $result.ResourceType = "BranchProtection"
        $result.ResourceName = "$RepoName/$BranchName"
        $result.Status = "DryRun"
        $result.ErrorMessage = ""
        return $result
    }

    $result = [OperationResult]::new()
    $result.ResourceType = "BranchProtection"
    $result.ResourceName = "$RepoName/$BranchName"
    $result.Status = "Failed"
    $result.ErrorMessage = ""

    # Resolve the owner (handle @me)
    if ($Owner -eq "@me") {
        $resolvedOwner = (& gh api user --jq '.login' 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $result.ErrorMessage = "Unable to resolve GitHub username from '@me': $resolvedOwner"
            Write-Host "[WARN] Branch protection for '$RepoName': Failed to resolve owner." -ForegroundColor Yellow
            Write-Host "       The script will continue with remaining operations." -ForegroundColor Yellow
            return $result
        }
    } else {
        $resolvedOwner = $Owner
    }

    # Verify the repository exists before attempting to set protection
    $repoCheck = & gh repo view "$resolvedOwner/$RepoName" 2>&1
    if ($LASTEXITCODE -ne 0) {
        $result.ErrorMessage = "Repository '$resolvedOwner/$RepoName' does not exist or is not accessible."
        Write-Host "[WARN] Branch protection for '$RepoName/$BranchName': Repository not found or not accessible." -ForegroundColor Yellow
        Write-Host "       The script will continue with remaining operations." -ForegroundColor Yellow
        return $result
    }

    # Build the JSON body for the branch protection PUT request
    $protectionBody = '{"required_status_checks":{"strict":true,"contexts":["ci/pipeline-check"]},"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":1},"restrictions":null}'

    # Apply branch protection via gh api PUT using a temp file for the JSON body
    $apiPath = "repos/$resolvedOwner/$RepoName/branches/$BranchName/protection"

    Write-Host "[INFO] Applying branch protection to '$resolvedOwner/$RepoName' branch '$BranchName'..." -ForegroundColor Cyan

    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tempFile, $protectionBody)

        $apiOutput = & gh api $apiPath --method PUT --input $tempFile 2>&1
        $apiExitCode = $LASTEXITCODE
    } finally {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }

    if ($apiExitCode -ne 0) {
        $errorString = $apiOutput | Out-String
        $result.ErrorMessage = "Failed to set branch protection on '$resolvedOwner/$RepoName/$BranchName': $errorString"
        Write-Host "[WARN] Branch protection for '$RepoName/$BranchName': $errorString" -ForegroundColor Yellow
        Write-Host "       The script will continue with remaining operations." -ForegroundColor Yellow
        return $result
    }

    # Success
    Write-Host "[OK] Branch protection is active on '$resolvedOwner/$RepoName' branch '$BranchName'." -ForegroundColor Green
    Write-Host "     - Required reviewers: 1" -ForegroundColor Green
    Write-Host "     - Enforce for admins: Yes (no direct pushes)" -ForegroundColor Green
    Write-Host "     - Required status checks: ci/pipeline-check" -ForegroundColor Green

    $result.Status = "Created"
    $result.ErrorMessage = ""
    return $result
}

# ==============================================================================
# Main Orchestration — Continue-on-Failure Pattern
# ==============================================================================

# --- Step 1: Validate Prerequisites (exit 2 on failure) ---
Test-Prerequisites

# Initialize results collection
$results = @()

# Resolve the owner once for use in dependent operations
if ($GitHubOwner -eq "@me") {
    if ($script:DryRun) {
        # In DryRun mode, use a placeholder since we won't make API calls
        $script:ResolvedOwner = "(authenticated-user)"
        Write-Host "[DRY RUN] Would resolve '@me' to authenticated GitHub username" -ForegroundColor Yellow
    } else {
        $script:ResolvedOwner = (& gh api user --jq '.login' 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Failed to resolve GitHub username from '@me'." -ForegroundColor Red
            exit $EXIT_VALIDATION_FAILURE
        }
    }
} else {
    $script:ResolvedOwner = $GitHubOwner
}

# --- Step 2: Create Project Board ---
try {
    $boardResult = New-ProjectBoard -Owner $GitHubOwner -ProjectPrefix $ProjectPrefix
    $results += $boardResult
} catch {
    $boardResult = [OperationResult]::new()
    $boardResult.ResourceType = "ProjectBoard"
    $boardResult.ResourceName = "Azure DevSecOps Pipeline Architecture"
    $boardResult.Status = "Failed"
    $boardResult.ErrorMessage = $_.Exception.Message
    $results += $boardResult
}

# --- Step 3: Add Board Items (depends on board) ---
if ($boardResult.Status -eq "Created" -or $boardResult.Status -eq "AlreadyExisted" -or $boardResult.Status -eq "Updated" -or $boardResult.Status -eq "DryRun") {
    try {
        $boardItemsResult = Add-BoardItems -Owner $GitHubOwner
        $results += $boardItemsResult
    } catch {
        $boardItemsResult = [OperationResult]::new()
        $boardItemsResult.ResourceType = "BoardItems"
        $boardItemsResult.ResourceName = "Project Board Tasks"
        $boardItemsResult.Status = "Failed"
        $boardItemsResult.ErrorMessage = $_.Exception.Message
        $results += $boardItemsResult
    }
}

# --- Step 4: Create Platform Repository ---
try {
    $platformResult = New-PlatformRepository -Owner $GitHubOwner -ProjectPrefix $ProjectPrefix
    $results += $platformResult
} catch {
    $platformResult = [OperationResult]::new()
    $platformResult.ResourceType = "Repository"
    $platformResult.ResourceName = "$ProjectPrefix-platform-infrastructure"
    $platformResult.Status = "Failed"
    $platformResult.ErrorMessage = $_.Exception.Message
    $results += $platformResult
}

# --- Step 5: Initialize Platform Repository Files (depends on platform repo) ---
$platformRepoName = "$ProjectPrefix-platform-infrastructure"
$platformRepoPath = $null

if ($platformResult.Status -eq "Created" -or $platformResult.Status -eq "DryRun") {
    if ($script:DryRun) {
        Write-Host "[DRY RUN] Would initialize platform repository file structure (main.tf, variables.tf, etc.)" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would create child modules (network, aks, security)" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would create GitHub Actions pipeline (terraform-deploy.yml)" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would create README.md documentation" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would commit and push all files to main branch" -ForegroundColor Yellow
    } else {
    # Find the cloned repo path — it was moved to a temp directory by New-PlatformRepository
    $tempDirs = Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Directory -Filter "phase1-setup-*" |
        Sort-Object LastWriteTime -Descending
    foreach ($dir in $tempDirs) {
        $candidatePath = Join-Path $dir.FullName $platformRepoName
        if (Test-Path $candidatePath) {
            $platformRepoPath = $candidatePath
            break
        }
    }

    if ($platformRepoPath -and (Test-Path $platformRepoPath)) {
        try {
            Initialize-PlatformRepoFiles -RepoPath $platformRepoPath
            $initPlatformResult = [OperationResult]::new()
            $initPlatformResult.ResourceType = "RepoFiles"
            $initPlatformResult.ResourceName = "$platformRepoName/files"
            $initPlatformResult.Status = "Created"
            $initPlatformResult.ErrorMessage = ""
            $results += $initPlatformResult
        } catch {
            $initPlatformResult = [OperationResult]::new()
            $initPlatformResult.ResourceType = "RepoFiles"
            $initPlatformResult.ResourceName = "$platformRepoName/files"
            $initPlatformResult.Status = "Failed"
            $initPlatformResult.ErrorMessage = $_.Exception.Message
            $results += $initPlatformResult
        }

        # --- Initialize Platform Modules ---
        try {
            Initialize-PlatformModules -RepoPath $platformRepoPath
            $modulesResult = [OperationResult]::new()
            $modulesResult.ResourceType = "RepoFiles"
            $modulesResult.ResourceName = "$platformRepoName/modules"
            $modulesResult.Status = "Created"
            $modulesResult.ErrorMessage = ""
            $results += $modulesResult
        } catch {
            $modulesResult = [OperationResult]::new()
            $modulesResult.ResourceType = "RepoFiles"
            $modulesResult.ResourceName = "$platformRepoName/modules"
            $modulesResult.Status = "Failed"
            $modulesResult.ErrorMessage = $_.Exception.Message
            $results += $modulesResult
        }

        # --- Initialize Platform Pipeline ---
        try {
            Initialize-PlatformPipeline -RepoPath $platformRepoPath
            $pipelineResult = [OperationResult]::new()
            $pipelineResult.ResourceType = "RepoFiles"
            $pipelineResult.ResourceName = "$platformRepoName/pipeline"
            $pipelineResult.Status = "Created"
            $pipelineResult.ErrorMessage = ""
            $results += $pipelineResult
        } catch {
            $pipelineResult = [OperationResult]::new()
            $pipelineResult.ResourceType = "RepoFiles"
            $pipelineResult.ResourceName = "$platformRepoName/pipeline"
            $pipelineResult.Status = "Failed"
            $pipelineResult.ErrorMessage = $_.Exception.Message
            $results += $pipelineResult
        }

        # --- Initialize Platform README ---
        try {
            Initialize-PlatformReadme -RepoPath $platformRepoPath
            $readmeResult = [OperationResult]::new()
            $readmeResult.ResourceType = "RepoFiles"
            $readmeResult.ResourceName = "$platformRepoName/README"
            $readmeResult.Status = "Created"
            $readmeResult.ErrorMessage = ""
            $results += $readmeResult
        } catch {
            $readmeResult = [OperationResult]::new()
            $readmeResult.ResourceType = "RepoFiles"
            $readmeResult.ResourceName = "$platformRepoName/README"
            $readmeResult.Status = "Failed"
            $readmeResult.ErrorMessage = $_.Exception.Message
            $results += $readmeResult
        }

        # --- Push Platform Repository Files ---
        try {
            $pushSuccess = Push-PlatformRepoFiles -RepoPath $platformRepoPath
            $pushResult = [OperationResult]::new()
            $pushResult.ResourceType = "RepoFiles"
            $pushResult.ResourceName = "$platformRepoName/push"
            $pushResult.Status = if ($pushSuccess) { "Created" } else { "Failed" }
            $pushResult.ErrorMessage = if ($pushSuccess) { "" } else { "Push operation returned failure." }
            $results += $pushResult
        } catch {
            $pushResult = [OperationResult]::new()
            $pushResult.ResourceType = "RepoFiles"
            $pushResult.ResourceName = "$platformRepoName/push"
            $pushResult.Status = "Failed"
            $pushResult.ErrorMessage = $_.Exception.Message
            $results += $pushResult
        }
    } else {
        Write-Host "[WARN] Could not locate cloned platform repository path. Skipping file initialization." -ForegroundColor Yellow
    }
    } # end else (not DryRun)
}

# --- Step 6: Create Workload Repository ---
try {
    $workloadResult = New-WorkloadRepository -Owner $GitHubOwner -ProjectPrefix $ProjectPrefix
    $results += $workloadResult
} catch {
    $workloadResult = [OperationResult]::new()
    $workloadResult.ResourceType = "Repository"
    $workloadResult.ResourceName = "$ProjectPrefix-workload"
    $workloadResult.Status = "Failed"
    $workloadResult.ErrorMessage = $_.Exception.Message
    $results += $workloadResult
}

# --- Step 7: Initialize Workload Repository Files (depends on workload repo) ---
$workloadRepoName = "$ProjectPrefix-workload"
$workloadRepoPath = $null

if ($workloadResult.Status -eq "Created" -or $workloadResult.Status -eq "DryRun") {
    if ($script:DryRun) {
        Write-Host "[DRY RUN] Would initialize workload repository file structure (src/, docker/, .gitignore, README.md)" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Would commit and push all files to main branch" -ForegroundColor Yellow
    } else {
    # Find the cloned workload repo path
    $tempDirs = Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Directory -Filter "devsecops-setup-*" |
        Sort-Object LastWriteTime -Descending
    foreach ($dir in $tempDirs) {
        $candidatePath = Join-Path $dir.FullName $workloadRepoName
        if (Test-Path $candidatePath) {
            $workloadRepoPath = $candidatePath
            break
        }
    }

    # Also check current directory (gh repo create --clone puts it in CWD)
    if (-not $workloadRepoPath) {
        $cwdCandidate = Join-Path (Get-Location).Path $workloadRepoName
        if (Test-Path $cwdCandidate) {
            $workloadRepoPath = $cwdCandidate
        }
    }

    if ($workloadRepoPath -and (Test-Path $workloadRepoPath)) {
        try {
            $initSuccess = Initialize-WorkloadRepoFiles -RepoPath $workloadRepoPath
            $initWorkloadResult = [OperationResult]::new()
            $initWorkloadResult.ResourceType = "RepoFiles"
            $initWorkloadResult.ResourceName = "$workloadRepoName/files"
            $initWorkloadResult.Status = if ($initSuccess) { "Created" } else { "Failed" }
            $initWorkloadResult.ErrorMessage = if ($initSuccess) { "" } else { "Workload file initialization returned failure." }
            $results += $initWorkloadResult
        } catch {
            $initWorkloadResult = [OperationResult]::new()
            $initWorkloadResult.ResourceType = "RepoFiles"
            $initWorkloadResult.ResourceName = "$workloadRepoName/files"
            $initWorkloadResult.Status = "Failed"
            $initWorkloadResult.ErrorMessage = $_.Exception.Message
            $results += $initWorkloadResult
        }
    } else {
        Write-Host "[WARN] Could not locate cloned workload repository path. Skipping file initialization." -ForegroundColor Yellow
    }
    } # end else (not DryRun)
}

# --- Step 8: Dependent Operations — Branch Protection ---
# Only apply branch protection if the repository was created or already exists

if ($platformResult.Status -eq "Created" -or $platformResult.Status -eq "AlreadyExisted" -or $platformResult.Status -eq "DryRun") {
    try {
        $platformProtectionResult = Set-BranchProtection -Owner $GitHubOwner -RepoName $platformRepoName
        $results += $platformProtectionResult
    } catch {
        $protResult = [OperationResult]::new()
        $protResult.ResourceType = "BranchProtection"
        $protResult.ResourceName = "$platformRepoName/main"
        $protResult.Status = "Failed"
        $protResult.ErrorMessage = $_.Exception.Message
        $results += $protResult
    }
}

if ($workloadResult.Status -eq "Created" -or $workloadResult.Status -eq "AlreadyExisted" -or $workloadResult.Status -eq "DryRun") {
    try {
        $workloadProtectionResult = Set-BranchProtection -Owner $GitHubOwner -RepoName $workloadRepoName
        $results += $workloadProtectionResult
    } catch {
        $protResult = [OperationResult]::new()
        $protResult.ResourceType = "BranchProtection"
        $protResult.ResourceName = "$workloadRepoName/main"
        $protResult.Status = "Failed"
        $protResult.ErrorMessage = $_.Exception.Message
        $results += $protResult
    }
}

# --- Step 9: Dependent Operations — Board Links ---
# Only link repos to board if both the board and the repo are available

$boardAvailable = ($boardResult.Status -eq "Created" -or $boardResult.Status -eq "AlreadyExisted" -or $boardResult.Status -eq "Updated" -or $boardResult.Status -eq "DryRun")

if ($boardAvailable -and ($platformResult.Status -eq "Created" -or $platformResult.Status -eq "AlreadyExisted" -or $platformResult.Status -eq "DryRun")) {
    $platformFullName = "$($script:ResolvedOwner)/$platformRepoName"
    try {
        $platformLinkResult = Add-BoardLink -Owner $script:ResolvedOwner -RepoFullName $platformFullName
        $results += $platformLinkResult
    } catch {
        $linkResult = [OperationResult]::new()
        $linkResult.ResourceType = "BoardLink"
        $linkResult.ResourceName = $platformRepoName
        $linkResult.Status = "Failed"
        $linkResult.ErrorMessage = $_.Exception.Message
        $results += $linkResult
    }
}

if ($boardAvailable -and ($workloadResult.Status -eq "Created" -or $workloadResult.Status -eq "AlreadyExisted" -or $workloadResult.Status -eq "DryRun")) {
    $workloadFullName = "$($script:ResolvedOwner)/$workloadRepoName"
    try {
        $workloadLinkResult = Add-BoardLink -Owner $script:ResolvedOwner -RepoFullName $workloadFullName
        $results += $workloadLinkResult
    } catch {
        $linkResult = [OperationResult]::new()
        $linkResult.ResourceType = "BoardLink"
        $linkResult.ResourceName = $workloadRepoName
        $linkResult.Status = "Failed"
        $linkResult.ErrorMessage = $_.Exception.Message
        $results += $linkResult
    }
}

# --- Step 10: Output Summary and Exit ---
$exitCode = Write-Summary -Results $results
exit $exitCode
