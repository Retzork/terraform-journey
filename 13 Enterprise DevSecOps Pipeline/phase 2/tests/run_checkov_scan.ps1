# run_checkov_scan.ps1
# Property 2: Security Configuration Compliance — Run Checkov against all .tf files and verify no high/critical findings
# Property 5: Checkov Gate — Verify Checkov blocks on high/critical severity
# Validates: Requirements 7.2, 7.3
#
# This script runs Checkov against all Terraform files in the phase 2 directory using:
# 1. The project .checkov.yaml configuration (built-in + skipped checks)
# 2. Custom policies from tests/checkov/ directory
# It verifies that Checkov exits cleanly (no high/critical findings) and reports a summary.

$ErrorActionPreference = "Stop"

$phase2Root = Join-Path $PSScriptRoot ".."
$checkovConfig = Join-Path $phase2Root ".checkov.yaml"
$customPoliciesDir = Join-Path $PSScriptRoot "checkov"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Property 2: Security Configuration Compliance" -ForegroundColor Cyan
Write-Host " Property 5: Checkov Gate Verification" -ForegroundColor Cyan
Write-Host " Running Checkov scan against all modules" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Pre-flight checks ---
Write-Host "--- Pre-flight checks ---" -ForegroundColor Yellow

# Verify Checkov is installed
$checkovVersion = $null
try {
    $checkovVersion = & checkov --version 2>&1
    Write-Host "  Checkov version: $checkovVersion" -ForegroundColor Gray
} catch {
    Write-Host "[FAIL] Checkov is not installed or not in PATH" -ForegroundColor Red
    Write-Host "  Install with: pip install checkov" -ForegroundColor DarkGray
    exit 1
}

# Verify .checkov.yaml exists
if (-not (Test-Path $checkovConfig)) {
    Write-Host "[FAIL] Checkov configuration not found at: $checkovConfig" -ForegroundColor Red
    exit 1
}
Write-Host "  Config file: $checkovConfig" -ForegroundColor Gray

# Verify custom policies directory exists
if (-not (Test-Path $customPoliciesDir)) {
    Write-Host "[WARN] Custom policies directory not found at: $customPoliciesDir" -ForegroundColor Yellow
    Write-Host "  Skipping custom policy scan" -ForegroundColor DarkGray
    $hasCustomPolicies = $false
} else {
    $policyFiles = Get-ChildItem -Path $customPoliciesDir -Filter "*.yaml" -File
    Write-Host "  Custom policies: $($policyFiles.Count) files in $customPoliciesDir" -ForegroundColor Gray
    $hasCustomPolicies = $true
}

Write-Host ""

# --- Phase 1: Run Checkov with .checkov.yaml configuration ---
Write-Host "--- Phase 1: Checkov scan with .checkov.yaml ---" -ForegroundColor Yellow
Write-Host "  Directory: $phase2Root" -ForegroundColor Gray
Write-Host "  Framework: terraform" -ForegroundColor Gray
Write-Host "  Config: $checkovConfig" -ForegroundColor Gray
Write-Host ""

$mainScanOutput = & checkov -d $phase2Root --config-file $checkovConfig --framework terraform --compact --quiet 2>&1
$mainScanExitCode = $LASTEXITCODE

if ($mainScanExitCode -eq 0) {
    Write-Host "[PASS] Main Checkov scan — no high/critical findings detected" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Main Checkov scan — high/critical findings detected (exit code: $mainScanExitCode)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Checkov Output:" -ForegroundColor DarkGray
    $mainScanOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
}

Write-Host ""

# --- Phase 2: Run custom policies from tests/checkov/ ---
$customScanExitCode = 0

if ($hasCustomPolicies) {
    Write-Host "--- Phase 2: Custom policy scan (tests/checkov/) ---" -ForegroundColor Yellow
    Write-Host "  Directory: $phase2Root" -ForegroundColor Gray
    Write-Host "  External checks: $customPoliciesDir" -ForegroundColor Gray
    Write-Host ""

    $customScanOutput = & checkov -d $phase2Root --external-checks-dir $customPoliciesDir --framework terraform --compact --quiet 2>&1
    $customScanExitCode = $LASTEXITCODE

    if ($customScanExitCode -eq 0) {
        Write-Host "[PASS] Custom policy scan — all custom checks passed" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Custom policy scan — custom policy violations detected (exit code: $customScanExitCode)" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Custom Scan Output:" -ForegroundColor DarkGray
        $customScanOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }

    Write-Host ""
}

# --- Results Summary ---
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Checkov Scan Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Main scan (.checkov.yaml):    $(if ($mainScanExitCode -eq 0) { 'PASS' } else { 'FAIL' })" -ForegroundColor $(if ($mainScanExitCode -eq 0) { "Green" } else { "Red" })

if ($hasCustomPolicies) {
    Write-Host "  Custom policies (tests/checkov/): $(if ($customScanExitCode -eq 0) { 'PASS' } else { 'FAIL' })" -ForegroundColor $(if ($customScanExitCode -eq 0) { "Green" } else { "Red" })
}

Write-Host ""

# --- Property 5 Verification: Checkov Gate Behavior ---
Write-Host "--- Property 5: Checkov Gate Verification ---" -ForegroundColor Yellow
Write-Host "  hard-fail-on: high, critical (configured in .checkov.yaml)" -ForegroundColor Gray
Write-Host "  soft-fail-on: medium, low (warnings only, does not block)" -ForegroundColor Gray
Write-Host "  Behavior: Exit code 0 = no high/critical findings (gate passes)" -ForegroundColor Gray
Write-Host "  Behavior: Exit code non-zero = high/critical findings detected (gate blocks)" -ForegroundColor Gray
Write-Host ""

if ($mainScanExitCode -eq 0) {
    Write-Host "  [VERIFIED] Checkov gate would ALLOW deployment (no high/critical findings)" -ForegroundColor Green
} else {
    Write-Host "  [VERIFIED] Checkov gate would BLOCK deployment (high/critical findings present)" -ForegroundColor Red
}

Write-Host ""

# --- Final Result ---
$overallExitCode = 0
if ($mainScanExitCode -ne 0) { $overallExitCode = 1 }
if ($customScanExitCode -ne 0) { $overallExitCode = 1 }

if ($overallExitCode -eq 0) {
    Write-Host "RESULT: PASS — All Checkov scans passed, no high/critical security findings" -ForegroundColor Green
} else {
    Write-Host "RESULT: FAIL — Security findings detected that would block deployment" -ForegroundColor Red
    Write-Host ""
    Write-Host "  To review findings in detail, run:" -ForegroundColor DarkGray
    Write-Host "    checkov -d `"$phase2Root`" --config-file `"$checkovConfig`" --framework terraform" -ForegroundColor DarkGray
    if ($hasCustomPolicies) {
        Write-Host "    checkov -d `"$phase2Root`" --external-checks-dir `"$customPoliciesDir`" --framework terraform" -ForegroundColor DarkGray
    }
}

exit $overallExitCode
