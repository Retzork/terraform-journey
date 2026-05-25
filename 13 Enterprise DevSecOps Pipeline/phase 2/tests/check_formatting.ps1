# check_formatting.ps1
# Property 9: Formatting Compliance
# Validates: Requirements 8.5
#
# Runs `terraform fmt -check -recursive` on the phase 2 root directory
# and all child module directories. Reports any files that need formatting.
# Exits with non-zero code if any files are not properly formatted.

$ErrorActionPreference = "Stop"

# Determine the phase 2 root directory (parent of the tests directory)
$Phase2Root = Split-Path -Parent $PSScriptRoot

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Property 9: Formatting Compliance Check" -ForegroundColor Cyan
Write-Host " Validates: Requirements 8.5" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Checking Terraform formatting in: $Phase2Root"
Write-Host ""

# Run terraform fmt -check -recursive on the phase 2 root directory
# The -recursive flag checks all subdirectories including child modules
$fmtOutput = & terraform fmt -check -recursive $Phase2Root 2>&1

# Capture the exit code
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "[PASS] All Terraform files are properly formatted." -ForegroundColor Green
    Write-Host ""
    Write-Host "Directories checked:" -ForegroundColor Gray
    Write-Host "  - $Phase2Root (root module)" -ForegroundColor Gray
    Write-Host "  - $Phase2Root\modules\network" -ForegroundColor Gray
    Write-Host "  - $Phase2Root\modules\aks" -ForegroundColor Gray
    Write-Host "  - $Phase2Root\modules\acr" -ForegroundColor Gray
    Write-Host "  - $Phase2Root\modules\security" -ForegroundColor Gray
    Write-Host "  - $Phase2Root\modules\identity" -ForegroundColor Gray
    Write-Host "  - $Phase2Root\modules\compute" -ForegroundColor Gray
    exit 0
}
else {
    Write-Host "[FAIL] The following files need formatting:" -ForegroundColor Red
    Write-Host ""

    # terraform fmt -check outputs the list of files that need formatting
    $unformattedFiles = $fmtOutput | Where-Object { $_ -and $_ -notmatch "^$" }

    foreach ($file in $unformattedFiles) {
        Write-Host "  - $file" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "To fix formatting, run:" -ForegroundColor Cyan
    Write-Host "  terraform fmt -recursive `"$Phase2Root`"" -ForegroundColor White
    Write-Host ""
    exit 1
}
