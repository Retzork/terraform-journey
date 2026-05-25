#Requires -Version 5.1
<#
.SYNOPSIS
    Phase 1 Teardown Script — DevSecOps Pipeline Organization
.DESCRIPTION
    Removes all Phase 1 organizational resources for cleanup/testing:
    - Platform Infrastructure repository
    - Workload repository
    - GitHub Projects (v2) board
    Enables repeatable testing cycles by cleanly removing all Phase 1 artifacts.
.PARAMETER ProjectPrefix
    Mandatory. The project prefix used for naming repositories (e.g., "devsecops").
    Repositories targeted: <ProjectPrefix>-platform-infrastructure and <ProjectPrefix>-workload.
.PARAMETER GitHubOwner
    Optional. The GitHub user or organization that owns the resources.
    Defaults to "@me" (the currently authenticated user).
.PARAMETER Force
    Optional switch. When specified, skips the confirmation prompt and proceeds
    immediately with resource deletion.
.EXAMPLE
    .\teardown-phase1.ps1 -ProjectPrefix "devsecops"
.EXAMPLE
    .\teardown-phase1.ps1 -ProjectPrefix "devsecops" -GitHubOwner "my-org"
.EXAMPLE
    .\teardown-phase1.ps1 -ProjectPrefix "devsecops" -Force
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPrefix,

    [Parameter(Mandatory = $false)]
    [string]$GitHubOwner = "@me",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# ==============================================================================
# Exit Code Constants
# ==============================================================================
$EXIT_SUCCESS = 0

# ==============================================================================
# Resolve Owner
# ==============================================================================
if ($GitHubOwner -eq "@me") {
    $resolvedOwner = (& gh api user --jq '.login' 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to resolve GitHub username from '@me'." -ForegroundColor Red
        Write-Host "        Ensure you are authenticated: gh auth login" -ForegroundColor Yellow
        exit 1
    }
} else {
    $resolvedOwner = $GitHubOwner
}

# ==============================================================================
# Resource Names
# ==============================================================================
$platformRepo = "$resolvedOwner/$ProjectPrefix-platform-infrastructure"
$workloadRepo = "$resolvedOwner/$ProjectPrefix-workload"
$boardTitle   = "Azure DevSecOps Pipeline Architecture"

# ==============================================================================
# Confirmation Prompt
# ==============================================================================
if (-not $Force.IsPresent) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Phase 1 Teardown — Resource Deletion" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The following resources will be PERMANENTLY deleted:" -ForegroundColor Red
    Write-Host "  - Repository: $platformRepo" -ForegroundColor White
    Write-Host "  - Repository: $workloadRepo" -ForegroundColor White
    Write-Host "  - Project Board: $boardTitle" -ForegroundColor White
    Write-Host ""

    $confirmation = Read-Host "Are you sure you want to proceed? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Teardown cancelled." -ForegroundColor Cyan
        exit $EXIT_SUCCESS
    }
    Write-Host ""
}

# ==============================================================================
# Delete Platform Repository
# ==============================================================================
Write-Host "Deleting repository '$platformRepo'..." -ForegroundColor Cyan

$viewOutput = & gh repo view $platformRepo 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[SKIP] Repository '$platformRepo' does not exist. Nothing to delete." -ForegroundColor Yellow
} else {
    $deleteOutput = & gh repo delete $platformRepo --yes 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Repository '$platformRepo' deleted successfully." -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to delete repository '$platformRepo': $deleteOutput" -ForegroundColor Red
    }
}

# ==============================================================================
# Delete Workload Repository
# ==============================================================================
Write-Host "Deleting repository '$workloadRepo'..." -ForegroundColor Cyan

$viewOutput = & gh repo view $workloadRepo 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[SKIP] Repository '$workloadRepo' does not exist. Nothing to delete." -ForegroundColor Yellow
} else {
    $deleteOutput = & gh repo delete $workloadRepo --yes 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Repository '$workloadRepo' deleted successfully." -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to delete repository '$workloadRepo': $deleteOutput" -ForegroundColor Red
    }
}

# ==============================================================================
# Delete Project Board
# ==============================================================================
Write-Host "Deleting project board '$boardTitle'..." -ForegroundColor Cyan

# Find the project board by title
$projectsJson = & gh project list --owner $resolvedOwner --format json --limit 100 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to list projects: $projectsJson" -ForegroundColor Red
} else {
    $projects = $projectsJson | ConvertFrom-Json
    $targetProject = $projects.projects | Where-Object { $_.title -eq $boardTitle }

    if (-not $targetProject) {
        Write-Host "[SKIP] Project board '$boardTitle' does not exist. Nothing to delete." -ForegroundColor Yellow
    } else {
        $projectNumber = $targetProject.number
        $deleteOutput = & gh project delete $projectNumber --owner $resolvedOwner 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Project board '$boardTitle' (number: $projectNumber) deleted successfully." -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Failed to delete project board '$boardTitle': $deleteOutput" -ForegroundColor Red
        }
    }
}

# ==============================================================================
# Summary
# ==============================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Phase 1 Teardown Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

exit $EXIT_SUCCESS
