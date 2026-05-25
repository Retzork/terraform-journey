# validate_modules.ps1
# Property 7: Module Independence — Run terraform validate on each module directory independently
# Validates: Requirements 8.3
#
# This script iterates over each module directory, runs terraform init and terraform validate
# independently, and reports pass/fail for each module. Exits with non-zero code if any module fails.

$ErrorActionPreference = "Stop"

$modulesPath = Join-Path $PSScriptRoot ".." "modules"
$modules = @("network", "acr", "security", "identity", "aks", "compute")

$failed = @()
$passed = @()

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Property 7: Module Independence Validation" -ForegroundColor Cyan
Write-Host " Running terraform validate on each module" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

foreach ($module in $modules) {
    $modulePath = Join-Path $modulesPath $module

    if (-not (Test-Path $modulePath)) {
        Write-Host "[FAIL] Module '$module' — directory not found at $modulePath" -ForegroundColor Red
        $failed += $module
        continue
    }

    Write-Host "--- Validating module: $module ---" -ForegroundColor Yellow

    # Run terraform init (required before validate)
    Write-Host "  Running terraform init..." -ForegroundColor Gray
    $initResult = & terraform -chdir="$modulePath" init -backend=false 2>&1
    $initExitCode = $LASTEXITCODE

    if ($initExitCode -ne 0) {
        Write-Host "[FAIL] Module '$module' — terraform init failed (exit code: $initExitCode)" -ForegroundColor Red
        Write-Host "  Output: $($initResult | Out-String)" -ForegroundColor DarkGray
        $failed += $module
        continue
    }

    # Run terraform validate
    Write-Host "  Running terraform validate..." -ForegroundColor Gray
    $validateResult = & terraform -chdir="$modulePath" validate 2>&1
    $validateExitCode = $LASTEXITCODE

    if ($validateExitCode -eq 0) {
        Write-Host "[PASS] Module '$module' — terraform validate succeeded" -ForegroundColor Green
        $passed += $module
    } else {
        Write-Host "[FAIL] Module '$module' — terraform validate failed (exit code: $validateExitCode)" -ForegroundColor Red
        Write-Host "  Output: $($validateResult | Out-String)" -ForegroundColor DarkGray
        $failed += $module
    }

    Write-Host ""
}

# Summary
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Validation Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Passed: $($passed.Count)/$($modules.Count) modules" -ForegroundColor $(if ($passed.Count -eq $modules.Count) { "Green" } else { "Yellow" })

if ($passed.Count -gt 0) {
    Write-Host "    $($passed -join ', ')" -ForegroundColor Green
}

if ($failed.Count -gt 0) {
    Write-Host "  Failed: $($failed.Count)/$($modules.Count) modules" -ForegroundColor Red
    Write-Host "    $($failed -join ', ')" -ForegroundColor Red
    Write-Host ""
    Write-Host "RESULT: FAIL — Not all modules validate independently" -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "RESULT: PASS — All modules validate independently" -ForegroundColor Green
    exit 0
}
