param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("apply", "destroy")]
    [string]$Action
)

$Phases = @(
    "phase1_networking",
    "phase2_data",
    "phase3_compute",
    "phase4_routing",
    "phase5_governance"
)
if ($Action -eq "destroy") {
    [array]::Reverse($Phases)
}

$TotalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($Phase in $Phases) {
    if (Test-Path -Path $Phase) {
        Write-Host "--- Starting $Action on $Phase ---" -ForegroundColor Cyan
        $PhaseStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        Push-Location $Phase
        
        # Execute terraform with auto-approve to ensure non-blocking sequential flow
        if ($Action -eq "apply") {
            terraform init -input=false; terraform apply -auto-approve -input=false
        } else {
            terraform destroy -auto-approve -input=false
        }
        
        $ExitCode = $LASTEXITCODE
        Pop-Location
        
        $PhaseStopwatch.Stop()
        if ($ExitCode -ne 0) {
            Write-Error "Action $Action failed in $Phase with exit code $ExitCode. Halting execution."
            exit $ExitCode
        }
        
        Write-Host "Completed $Phase in $($PhaseStopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Green
    } else {
        Write-Host "Skipping $Phase (Directory not found)" -ForegroundColor Yellow
    }
}

$TotalStopwatch.Stop()
Write-Host "Total execution time: $($TotalStopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
az network firewall list -o table