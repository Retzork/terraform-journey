#Requires -Version 5.1
<#
.SYNOPSIS
    Phase 1 Smoke Test Script - Post-Execution Verification
.DESCRIPTION
    Verifies that all Phase 1 resources were provisioned correctly by checking:
    - GitHub Projects (v2) board exists with correct title and custom fields
    - Both repositories exist with expected names
    - Branch protection is active on both repos' main branch
    - Both repositories are linked to the project board
    Outputs [PASS] or [FAIL] for each check and exits with code 0 (all pass) or 1 (any fail).
.PARAMETER ProjectPrefix
    Mandatory. The project prefix used for naming repositories (e.g., "devsecops").
.PARAMETER GitHubOwner
    Optional. The GitHub user or organization that owns the resources.
    Defaults to "@me" (the currently authenticated user).
.EXAMPLE
    .\test-phase1.ps1 -ProjectPrefix "devsecops"
.EXAMPLE
    .\test-phase1.ps1 -ProjectPrefix "devsecops" -GitHubOwner "my-org"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPrefix,

    [Parameter(Mandatory = $false)]
    [string]$GitHubOwner = "@me"
)

# ==============================================================================
# Configuration
# ==============================================================================
$BOARD_TITLE = "Azure DevSecOps Pipeline Architecture"
$PLATFORM_REPO = "$ProjectPrefix-platform-infrastructure"
$WORKLOAD_REPO = "$ProjectPrefix-workload"

# Track test results
$script:totalTests = 0
$script:passedTests = 0
$script:failedTests = 0

# ==============================================================================
# Helper Functions
# ==============================================================================
function Write-TestResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,

        [Parameter(Mandatory = $true)]
        [bool]$Passed,

        [Parameter(Mandatory = $false)]
        [string]$Detail = ""
    )

    $script:totalTests++

    if ($Passed) {
        $script:passedTests++
        Write-Host "[PASS] $TestName" -ForegroundColor Green
    } else {
        $script:failedTests++
        $message = "[FAIL] $TestName"
        if ($Detail) {
            $message += " - $Detail"
        }
        Write-Host $message -ForegroundColor Red
    }
}

function Resolve-Owner {
    <#
    .SYNOPSIS
        Resolves the GitHub owner, handling the "@me" shorthand.
    #>
    param([string]$Owner)

    if ($Owner -eq "@me") {
        $resolved = & gh api user --jq '.login' 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] Unable to resolve GitHub username from '@me'. Ensure 'gh auth login' is complete." -ForegroundColor Red
            exit 1
        }
        return $resolved.Trim()
    }
    return $Owner
}

# ==============================================================================
# Main Execution
# ==============================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Phase 1 Smoke Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Resolve the owner
$resolvedOwner = Resolve-Owner -Owner $GitHubOwner

Write-Host "Owner:   $resolvedOwner"
Write-Host "Prefix:  $ProjectPrefix"
Write-Host ""
Write-Host "----------------------------------------"
Write-Host ""

# ==============================================================================
# Test 1: Project Board Exists with Correct Title
# ==============================================================================
$boardExists = $false
$projectNumber = $null

try {
    $projectsJson = & gh project list --owner $resolvedOwner --format json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $projects = $projectsJson | ConvertFrom-Json
        $matchingProject = $projects.projects | Where-Object { $_.title -eq $BOARD_TITLE }
        if ($matchingProject) {
            $boardExists = $true
            $projectNumber = $matchingProject.number
        }
    }
} catch {
    # Handled below via $boardExists
}

Write-TestResult -TestName "Project board '$BOARD_TITLE' exists" -Passed $boardExists -Detail $(if (-not $boardExists) { "Board not found under owner '$resolvedOwner'" } else { "" })

# ==============================================================================
# Test 2: Project Board Has "Phase" Custom Field
# ==============================================================================
$hasPhaseField = $false

if ($boardExists -and $projectNumber) {
    try {
        $fieldsJson = & gh project field-list $projectNumber --owner $resolvedOwner --format json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $fields = $fieldsJson | ConvertFrom-Json
            $phaseField = $fields.fields | Where-Object { $_.name -eq "Phase" }
            if ($phaseField) {
                $hasPhaseField = $true
            }
        }
    } catch {
        # Handled below
    }
}

Write-TestResult -TestName "Project board has 'Phase' custom field" -Passed $hasPhaseField -Detail $(if (-not $hasPhaseField) { if (-not $boardExists) { "Skipped (board not found)" } else { "'Phase' field not found on board" } } else { "" })

# ==============================================================================
# Test 3: Platform Repository Exists
# ==============================================================================
$platformRepoExists = $false

try {
    $null = & gh repo view "$resolvedOwner/$PLATFORM_REPO" --json name 2>&1
    if ($LASTEXITCODE -eq 0) {
        $platformRepoExists = $true
    }
} catch {
    # Handled below
}

Write-TestResult -TestName "Platform repository '$PLATFORM_REPO' exists" -Passed $platformRepoExists -Detail $(if (-not $platformRepoExists) { "Repository '$resolvedOwner/$PLATFORM_REPO' not found" } else { "" })

# ==============================================================================
# Test 4: Workload Repository Exists
# ==============================================================================
$workloadRepoExists = $false

try {
    $null = & gh repo view "$resolvedOwner/$WORKLOAD_REPO" --json name 2>&1
    if ($LASTEXITCODE -eq 0) {
        $workloadRepoExists = $true
    }
} catch {
    # Handled below
}

Write-TestResult -TestName "Workload repository '$WORKLOAD_REPO' exists" -Passed $workloadRepoExists -Detail $(if (-not $workloadRepoExists) { "Repository '$resolvedOwner/$WORKLOAD_REPO' not found" } else { "" })

# ==============================================================================
# Test 5: Branch Protection Active on Platform Repository
# ==============================================================================
$platformProtected = $false

if ($platformRepoExists) {
    try {
        $null = & gh api "repos/$resolvedOwner/$PLATFORM_REPO/branches/main/protection" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $platformProtected = $true
        }
    } catch {
        # Handled below
    }
}

Write-TestResult -TestName "Branch protection active on '$PLATFORM_REPO/main'" -Passed $platformProtected -Detail $(if (-not $platformProtected) { if (-not $platformRepoExists) { "Skipped (repository not found)" } else { "No branch protection rules found on main" } } else { "" })

# ==============================================================================
# Test 6: Branch Protection Active on Workload Repository
# ==============================================================================
$workloadProtected = $false

if ($workloadRepoExists) {
    try {
        $null = & gh api "repos/$resolvedOwner/$WORKLOAD_REPO/branches/main/protection" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $workloadProtected = $true
        }
    } catch {
        # Handled below
    }
}

Write-TestResult -TestName "Branch protection active on '$WORKLOAD_REPO/main'" -Passed $workloadProtected -Detail $(if (-not $workloadProtected) { if (-not $workloadRepoExists) { "Skipped (repository not found)" } else { "No branch protection rules found on main" } } else { "" })

# ==============================================================================
# Test 7: Platform Repository Linked to Project Board
# ==============================================================================
$platformLinked = $false

if ($boardExists -and $projectNumber -and $platformRepoExists) {
    try {
        $linkedReposJson = & gh project view $projectNumber --owner $resolvedOwner --format json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $projectView = $linkedReposJson | ConvertFrom-Json
            # Check if the platform repo appears in linked repositories
            if ($projectView.repositories) {
                $platformLinked = $projectView.repositories | Where-Object { $_.name -eq $PLATFORM_REPO }
                $platformLinked = [bool]$platformLinked
            }
        }

        # Fallback: try gh api to check linked repos
        if (-not $platformLinked) {
            $linkedJson = & gh api "graphql" -f query="query { user(login: `"$resolvedOwner`") { projectV2(number: $projectNumber) { repositories(first: 50) { nodes { name } } } } }" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $linkedData = $linkedJson | ConvertFrom-Json
                $repoNodes = $linkedData.data.user.projectV2.repositories.nodes
                if (-not $repoNodes) {
                    # Try organization path
                    $linkedJson = & gh api "graphql" -f query="query { organization(login: `"$resolvedOwner`") { projectV2(number: $projectNumber) { repositories(first: 50) { nodes { name } } } } }" 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $linkedData = $linkedJson | ConvertFrom-Json
                        $repoNodes = $linkedData.data.organization.projectV2.repositories.nodes
                    }
                }
                if ($repoNodes) {
                    $platformLinked = [bool]($repoNodes | Where-Object { $_.name -eq $PLATFORM_REPO })
                }
            }
        }
    } catch {
        # Handled below
    }
}

Write-TestResult -TestName "Platform repository linked to project board" -Passed $platformLinked -Detail $(if (-not $platformLinked) { if (-not $boardExists) { "Skipped (board not found)" } elseif (-not $platformRepoExists) { "Skipped (repository not found)" } else { "Link not detected" } } else { "" })

# ==============================================================================
# Test 8: Workload Repository Linked to Project Board
# ==============================================================================
$workloadLinked = $false

if ($boardExists -and $projectNumber -and $workloadRepoExists) {
    try {
        # Reuse the GraphQL approach for workload repo
        $linkedJson = & gh api "graphql" -f query="query { user(login: `"$resolvedOwner`") { projectV2(number: $projectNumber) { repositories(first: 50) { nodes { name } } } } }" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $linkedData = $linkedJson | ConvertFrom-Json
            $repoNodes = $linkedData.data.user.projectV2.repositories.nodes
            if (-not $repoNodes) {
                # Try organization path
                $linkedJson = & gh api "graphql" -f query="query { organization(login: `"$resolvedOwner`") { projectV2(number: $projectNumber) { repositories(first: 50) { nodes { name } } } } }" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $linkedData = $linkedJson | ConvertFrom-Json
                    $repoNodes = $linkedData.data.organization.projectV2.repositories.nodes
                }
            }
            if ($repoNodes) {
                $workloadLinked = [bool]($repoNodes | Where-Object { $_.name -eq $WORKLOAD_REPO })
            }
        }
    } catch {
        # Handled below
    }
}

Write-TestResult -TestName "Workload repository linked to project board" -Passed $workloadLinked -Detail $(if (-not $workloadLinked) { if (-not $boardExists) { "Skipped (board not found)" } elseif (-not $workloadRepoExists) { "Skipped (repository not found)" } else { "Link not detected" } } else { "" })

# ==============================================================================
# Summary
# ==============================================================================
Write-Host ""
Write-Host "----------------------------------------"
Write-Host ""
Write-Host "Results: $($script:passedTests) passed, $($script:failedTests) failed, $($script:totalTests) total"

if ($script:failedTests -gt 0) {
    Write-Host ""
    Write-Host "SMOKE TESTS FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "ALL SMOKE TESTS PASSED" -ForegroundColor Green
    exit 0
}
