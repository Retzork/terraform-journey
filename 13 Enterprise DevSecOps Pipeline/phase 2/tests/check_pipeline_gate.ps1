# check_pipeline_gate.ps1
# Property 5: Checkov Gate
# Validates: Requirements 7.3
#
# Reads the GitHub Actions workflow file (terraform-phase2.yml) and verifies
# the dependency chain ensures terraform-apply cannot run unless security-scan passes.
# Dependency chain: security-scan → terraform-plan → terraform-apply
#
# Checks:
#   1. terraform-plan job has `needs: security-scan`
#   2. terraform-apply job has `needs: terraform-plan`
#
# Exits with non-zero code if the gate structure is incorrect.

$ErrorActionPreference = "Stop"

# Determine the phase 2 root directory (parent of the tests directory)
$Phase2Root = Split-Path -Parent $PSScriptRoot

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Property 5: Checkov Gate Validation" -ForegroundColor Cyan
Write-Host " Validates: Requirements 7.3" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Path to the workflow file
$WorkflowPath = Join-Path $Phase2Root ".github\workflows\terraform-phase2.yml"

Write-Host "Checking workflow file: $WorkflowPath"
Write-Host ""

# Verify the workflow file exists
if (-not (Test-Path $WorkflowPath)) {
    Write-Host "[FAIL] Workflow file not found: $WorkflowPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Expected the GitHub Actions workflow at:" -ForegroundColor Yellow
    Write-Host "  phase 2/.github/workflows/terraform-phase2.yml" -ForegroundColor Yellow
    exit 1
}

# Read the workflow file content
$workflowContent = Get-Content $WorkflowPath -Raw

# Track test results
$allPassed = $true
$testResults = @()

# ─────────────────────────────────────────────────────────────────────────────
# Check 1: Verify terraform-plan job depends on security-scan
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "Check 1: terraform-plan depends on security-scan" -ForegroundColor White

# Parse the YAML to find the terraform-plan job's needs field
# We look for the terraform-plan job block and check its needs declaration
$planJobPattern = '(?ms)^\s{2}terraform-plan:.*?(?=^\s{2}\w|\z)'
$planJobMatch = [regex]::Match($workflowContent, $planJobPattern)

if ($planJobMatch.Success) {
    $planJobBlock = $planJobMatch.Value

    # Check if needs includes security-scan
    $needsSecurityScan = $planJobBlock -match 'needs:\s*security-scan' -or
                         $planJobBlock -match 'needs:\s*\[.*security-scan.*\]'

    if ($needsSecurityScan) {
        Write-Host "  [PASS] terraform-plan has 'needs: security-scan'" -ForegroundColor Green
        $testResults += @{ Name = "terraform-plan needs security-scan"; Passed = $true }
    }
    else {
        Write-Host "  [FAIL] terraform-plan does NOT depend on security-scan" -ForegroundColor Red
        Write-Host "         The terraform-plan job must have 'needs: security-scan'" -ForegroundColor Yellow
        $testResults += @{ Name = "terraform-plan needs security-scan"; Passed = $false }
        $allPassed = $false
    }
}
else {
    Write-Host "  [FAIL] Could not find 'terraform-plan' job in workflow" -ForegroundColor Red
    $testResults += @{ Name = "terraform-plan needs security-scan"; Passed = $false }
    $allPassed = $false
}

Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# Check 2: Verify terraform-apply job depends on terraform-plan
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "Check 2: terraform-apply depends on terraform-plan" -ForegroundColor White

# Parse the YAML to find the terraform-apply job's needs field
$applyJobPattern = '(?ms)^\s{2}terraform-apply:.*?(?=^\s{2}\w|\z)'
$applyJobMatch = [regex]::Match($workflowContent, $applyJobPattern)

if ($applyJobMatch.Success) {
    $applyJobBlock = $applyJobMatch.Value

    # Check if needs includes terraform-plan
    $needsTerraformPlan = $applyJobBlock -match 'needs:\s*terraform-plan' -or
                          $applyJobBlock -match 'needs:\s*\[.*terraform-plan.*\]'

    if ($needsTerraformPlan) {
        Write-Host "  [PASS] terraform-apply has 'needs: terraform-plan'" -ForegroundColor Green
        $testResults += @{ Name = "terraform-apply needs terraform-plan"; Passed = $true }
    }
    else {
        Write-Host "  [FAIL] terraform-apply does NOT depend on terraform-plan" -ForegroundColor Red
        Write-Host "         The terraform-apply job must have 'needs: terraform-plan'" -ForegroundColor Yellow
        $testResults += @{ Name = "terraform-apply needs terraform-plan"; Passed = $false }
        $allPassed = $false
    }
}
else {
    Write-Host "  [FAIL] Could not find 'terraform-apply' job in workflow" -ForegroundColor Red
    $testResults += @{ Name = "terraform-apply needs terraform-plan"; Passed = $false }
    $allPassed = $false
}

Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# Check 3: Verify the complete dependency chain exists
# security-scan → terraform-plan → terraform-apply
# This ensures Checkov failure blocks the entire deployment
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "Check 3: Complete dependency chain (security-scan -> terraform-plan -> terraform-apply)" -ForegroundColor White

if ($testResults[0].Passed -and $testResults[1].Passed) {
    Write-Host "  [PASS] Dependency chain is complete:" -ForegroundColor Green
    Write-Host "         security-scan -> terraform-plan -> terraform-apply" -ForegroundColor Green
    Write-Host "         Checkov failure will block terraform-apply" -ForegroundColor Gray
    $testResults += @{ Name = "Complete dependency chain"; Passed = $true }
}
else {
    Write-Host "  [FAIL] Dependency chain is broken!" -ForegroundColor Red
    Write-Host "         Expected: security-scan -> terraform-plan -> terraform-apply" -ForegroundColor Yellow
    Write-Host "         A broken chain means Checkov failures may not block deployment" -ForegroundColor Yellow
    $testResults += @{ Name = "Complete dependency chain"; Passed = $false }
    $allPassed = $false
}

Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Results Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$passCount = ($testResults | Where-Object { $_.Passed }).Count
$failCount = ($testResults | Where-Object { -not $_.Passed }).Count

foreach ($result in $testResults) {
    $status = if ($result.Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($result.Passed) { "Green" } else { "Red" }
    Write-Host "  $status $($result.Name)" -ForegroundColor $color
}

Write-Host ""
Write-Host "Total: $passCount passed, $failCount failed" -ForegroundColor $(if ($allPassed) { "Green" } else { "Red" })
Write-Host ""

if ($allPassed) {
    Write-Host "Pipeline gate structure is correct. Checkov failure will block deployment." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Pipeline gate structure is INCORRECT. Fix the workflow dependency chain." -ForegroundColor Red
    Write-Host ""
    Write-Host "Required structure:" -ForegroundColor Cyan
    Write-Host "  jobs:" -ForegroundColor White
    Write-Host "    security-scan:    # Runs Checkov" -ForegroundColor White
    Write-Host "    terraform-plan:" -ForegroundColor White
    Write-Host "      needs: security-scan" -ForegroundColor White
    Write-Host "    terraform-apply:" -ForegroundColor White
    Write-Host "      needs: terraform-plan" -ForegroundColor White
    exit 1
}
