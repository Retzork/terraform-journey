# check_idempotency.ps1
# Property 6: Idempotent Apply
# Validates: Requirements 9.2
#
# Verifies that running `terraform plan` after a successful apply shows 0 changes.
# Uses -detailed-exitcode to determine the plan result:
#   Exit code 0 = No changes (infrastructure matches configuration) — PASS
#   Exit code 2 = Changes detected (infrastructure drift or non-idempotent resources) — FAIL
#   Exit code 1 = Error running plan — ERROR
#
# Prerequisites: A successful `terraform apply` must have been run first.

$ErrorActionPreference = "Stop"

# Determine the phase 2 root directory (parent of the tests directory)
$Phase2Root = Split-Path -Parent $PSScriptRoot
$TfVarsFile = Join-Path $Phase2Root "environments\dev.tfvars"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Property 6: Idempotent Apply Check" -ForegroundColor Cyan
Write-Host " Validates: Requirements 9.2" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Phase 2 root: $Phase2Root"
Write-Host "Var file:     $TfVarsFile"
Write-Host ""

# Verify the tfvars file exists
if (-not (Test-Path $TfVarsFile)) {
    Write-Host "[ERROR] Variable file not found: $TfVarsFile" -ForegroundColor Red
    Write-Host "  Ensure the environments/dev.tfvars file exists." -ForegroundColor Yellow
    exit 1
}

# Verify terraform state exists (indicates a prior apply has been run)
$stateCheck = & terraform -chdir="$Phase2Root" state list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] No Terraform state found. A successful apply must be run first." -ForegroundColor Red
    Write-Host "  Run 'terraform apply -var-file=`"environments/dev.tfvars`"' before this test." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  State check output:" -ForegroundColor Gray
    Write-Host "  $stateCheck" -ForegroundColor Gray
    exit 1
}

Write-Host "Running terraform plan with -detailed-exitcode..." -ForegroundColor Gray
Write-Host ""

# Run terraform plan with -detailed-exitcode
# Exit codes: 0 = no changes, 1 = error, 2 = changes detected
$planOutput = & terraform -chdir="$Phase2Root" plan -var-file="environments/dev.tfvars" -detailed-exitcode 2>&1
$planExitCode = $LASTEXITCODE

Write-Host ""

switch ($planExitCode) {
    0 {
        Write-Host "[PASS] Infrastructure is idempotent — no changes detected." -ForegroundColor Green
        Write-Host ""
        Write-Host "  terraform plan reported 0 resources to add, change, or destroy." -ForegroundColor Gray
        Write-Host "  This confirms Requirement 9.2: a second consecutive apply with no" -ForegroundColor Gray
        Write-Host "  configuration changes reports 0 additions, 0 changes, 0 destructions." -ForegroundColor Gray
        exit 0
    }
    2 {
        Write-Host "[FAIL] Changes detected — infrastructure is NOT idempotent." -ForegroundColor Red
        Write-Host ""
        Write-Host "  terraform plan reported changes that would be applied." -ForegroundColor Yellow
        Write-Host "  This violates Requirement 9.2: running apply a second time should" -ForegroundColor Yellow
        Write-Host "  result in 0 resources added, 0 changed, and 0 destroyed." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Plan output (investigate non-idempotent resources):" -ForegroundColor Cyan
        Write-Host ""

        # Display the plan output to help identify the non-idempotent resources
        foreach ($line in $planOutput) {
            if ($line -match "^[\s]*[~+\-]") {
                Write-Host "  $line" -ForegroundColor Yellow
            }
            elseif ($line -match "Plan:") {
                Write-Host "  $line" -ForegroundColor Red
            }
        }

        Write-Host ""
        Write-Host "  To fix: investigate the resources shown above and ensure they" -ForegroundColor Cyan
        Write-Host "  do not trigger changes on subsequent applies." -ForegroundColor Cyan
        exit 1
    }
    1 {
        Write-Host "[ERROR] Terraform plan failed with an error." -ForegroundColor Red
        Write-Host ""
        Write-Host "  This may indicate:" -ForegroundColor Yellow
        Write-Host "    - Missing or invalid credentials (ARM_* environment variables)" -ForegroundColor Yellow
        Write-Host "    - Backend configuration issues" -ForegroundColor Yellow
        Write-Host "    - Syntax errors in Terraform configuration" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Error output:" -ForegroundColor Cyan

        foreach ($line in $planOutput) {
            Write-Host "  $line" -ForegroundColor Gray
        }

        exit 1
    }
    default {
        Write-Host "[ERROR] Unexpected exit code from terraform plan: $planExitCode" -ForegroundColor Red
        Write-Host ""

        foreach ($line in $planOutput) {
            Write-Host "  $line" -ForegroundColor Gray
        }

        exit 1
    }
}
