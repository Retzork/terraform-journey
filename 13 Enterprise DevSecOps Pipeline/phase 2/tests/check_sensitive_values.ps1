# =============================================================================
# Property 4: Sensitive Value Protection
# Validates: Requirements 12.2, 12.3
#
# Verifies all sensitive outputs have `sensitive = true` flag and no secrets
# appear in committed files. Scans outputs.tf files for outputs referencing
# sensitive data (kube_config, password, secret, key) and ensures they are
# marked sensitive. Also checks that no actual passwords or secrets appear in
# .tfvars files or other committed files.
# =============================================================================

param(
    [string]$Phase2Path = (Join-Path $PSScriptRoot "..")
)

$ErrorActionPreference = "Stop"
$violations = @()

# Resolve the phase 2 path
$Phase2Path = Resolve-Path -Path $Phase2Path -ErrorAction Stop

Write-Host "=== Property 4: Sensitive Value Protection ===" -ForegroundColor Cyan
Write-Host "Scanning directory: $Phase2Path" -ForegroundColor Gray
Write-Host ""

# =============================================================================
# Check 1: Scan all outputs.tf files for outputs that reference sensitive data
#           and verify they have `sensitive = true`
# =============================================================================

Write-Host "--- Check 1: Sensitive outputs must have sensitive = true ---" -ForegroundColor Yellow
Write-Host ""

# Patterns that indicate an output contains sensitive data
$sensitiveOutputPatterns = @(
    'kube_config',
    'password',
    'secret',
    'key',
    'connection_string',
    'credential',
    'token',
    'private_key',
    'client_secret'
)

# Build a regex pattern to match sensitive output names or values
$sensitiveNamePattern = ($sensitiveOutputPatterns | ForEach-Object { [regex]::Escape($_) }) -join '|'

# Find all outputs.tf files
$outputFiles = Get-ChildItem -Path $Phase2Path -Filter "outputs.tf" -Recurse -File |
    Where-Object { $_.FullName -notmatch '\.terraform' }

if ($outputFiles.Count -eq 0) {
    Write-Host "WARNING: No outputs.tf files found in $Phase2Path" -ForegroundColor Yellow
}
else {
    Write-Host "Found $($outputFiles.Count) outputs.tf file(s) to scan" -ForegroundColor Gray
    Write-Host ""

    foreach ($file in $outputFiles) {
        $relativePath = $file.FullName.Replace($Phase2Path, "phase 2")
        $content = Get-Content -Path $file.FullName -Raw
        $lines = Get-Content -Path $file.FullName

        # Parse output blocks
        $inOutputBlock = $false
        $outputName = ""
        $outputStartLine = 0
        $braceDepth = 0
        $hasSensitiveFlag = $false
        $isSensitiveOutput = $false
        $outputBlockContent = ""

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $trimmedLine = $line.TrimStart()

            # Detect output block start
            if ($trimmedLine -match '^output\s+"([^"]+)"') {
                $inOutputBlock = $true
                $outputName = $Matches[1]
                $outputStartLine = $i + 1
                $braceDepth = 0
                $hasSensitiveFlag = $false
                $isSensitiveOutput = $false
                $outputBlockContent = ""
            }

            if ($inOutputBlock) {
                $outputBlockContent += $line + "`n"

                # Track brace depth
                $openBraces = ([regex]::Matches($line, '\{')).Count
                $closeBraces = ([regex]::Matches($line, '\}')).Count
                $braceDepth += $openBraces - $closeBraces

                # Check if this output name matches sensitive patterns
                if ($outputName -match $sensitiveNamePattern) {
                    $isSensitiveOutput = $true
                }

                # Check if the value references sensitive data
                if ($trimmedLine -match 'value\s*=' -and $trimmedLine -match $sensitiveNamePattern) {
                    $isSensitiveOutput = $true
                }

                # Check for sensitive = true flag
                if ($trimmedLine -match '^\s*sensitive\s*=\s*true') {
                    $hasSensitiveFlag = $true
                }

                # End of output block
                if ($braceDepth -eq 0 -and $openBraces -gt 0) {
                    # If this is a sensitive output without the flag, record violation
                    if ($isSensitiveOutput -and -not $hasSensitiveFlag) {
                        $violations += [PSCustomObject]@{
                            Check       = "Sensitive Output Missing Flag"
                            File        = $relativePath
                            Line        = $outputStartLine
                            Detail      = "Output '$outputName' references sensitive data but lacks 'sensitive = true'"
                            Severity    = "HIGH"
                        }
                    }
                    $inOutputBlock = $false
                }
            }
        }
    }
}

$check1Violations = $violations.Count
Write-Host "Check 1 complete: $check1Violations violation(s) found" -ForegroundColor $(if ($check1Violations -eq 0) { "Green" } else { "Red" })
Write-Host ""

# =============================================================================
# Check 2: Scan .tfvars files (except .example) for password/secret values
# =============================================================================

Write-Host "--- Check 2: No secrets in .tfvars files ---" -ForegroundColor Yellow
Write-Host ""

# Patterns that indicate a secret value is present in a .tfvars file
$secretValuePatterns = @(
    @{
        Name    = "Password Variable Assignment"
        Pattern = '^\s*(vm_admin_password|admin_password|password|db_password)\s*=\s*"[^"]*[^"]+"'
    },
    @{
        Name    = "Secret Variable Assignment"
        Pattern = '^\s*(client_secret|secret_key|api_secret|secret)\s*=\s*"[^"]*[^"]+"'
    },
    @{
        Name    = "Connection String with Password"
        Pattern = '(Password|pwd)\s*=\s*[^;"\s]+'
    },
    @{
        Name    = "ARM Client Secret"
        Pattern = '^\s*arm_client_secret\s*=\s*"[^"]+"'
    }
)

# Find all .tfvars files excluding .example files
$tfvarsFiles = Get-ChildItem -Path $Phase2Path -Filter "*.tfvars" -Recurse -File |
    Where-Object {
        $_.FullName -notmatch '\.terraform' -and
        $_.Name -notmatch '\.example' -and
        $_.Name -notmatch '\.sample'
    }

if ($tfvarsFiles.Count -eq 0) {
    Write-Host "No .tfvars files found (excluding .example files) — OK" -ForegroundColor Gray
}
else {
    Write-Host "Found $($tfvarsFiles.Count) .tfvars file(s) to scan" -ForegroundColor Gray

    foreach ($file in $tfvarsFiles) {
        $relativePath = $file.FullName.Replace($Phase2Path, "phase 2")
        $lines = Get-Content -Path $file.FullName

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $trimmedLine = $line.TrimStart()

            # Skip comments
            if ($trimmedLine.StartsWith("#") -or $trimmedLine.StartsWith("//")) {
                continue
            }

            foreach ($patternDef in $secretValuePatterns) {
                if ($line -match $patternDef.Pattern) {
                    $violations += [PSCustomObject]@{
                        Check       = "Secret in .tfvars File"
                        File        = $relativePath
                        Line        = ($i + 1)
                        Detail      = "$($patternDef.Name) — secrets must be passed via TF_VAR_* environment variables"
                        Severity    = "CRITICAL"
                    }
                }
            }
        }
    }
}

$check2Violations = $violations.Count - $check1Violations
Write-Host "Check 2 complete: $check2Violations violation(s) found" -ForegroundColor $(if ($check2Violations -eq 0) { "Green" } else { "Red" })
Write-Host ""

# =============================================================================
# Check 3: Check that no actual passwords or secrets appear in committed files
# =============================================================================

Write-Host "--- Check 3: No secrets in committed source files ---" -ForegroundColor Yellow
Write-Host ""

# Patterns that indicate actual secret values in source files
$committedSecretPatterns = @(
    @{
        Name    = "Hardcoded Password Value"
        Pattern = '(password|passwd|pwd)\s*=\s*"(?!(\$\{|\<|placeholder|changeme|CHANGE_ME|your-|example|dummy|test123))[A-Za-z0-9!@#$%^&*()_+\-=]{8,}"'
    },
    @{
        Name    = "Hardcoded API Key"
        Pattern = '(api_key|apikey|api-key)\s*=\s*"(?!(\$\{|\<|placeholder|changeme|CHANGE_ME|your-|example|dummy))[A-Za-z0-9\-_]{16,}"'
    },
    @{
        Name    = "Azure Client Secret Pattern"
        Pattern = '(client_secret|ARM_CLIENT_SECRET)\s*=\s*"[A-Za-z0-9\-_.~]{30,}"'
    },
    @{
        Name    = "Private Key Block"
        Pattern = '-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'
    },
    @{
        Name    = "Generic Secret Assignment"
        Pattern = '(secret|token)\s*=\s*"(?!(\$\{|\<|placeholder|changeme|CHANGE_ME|your-|example|dummy))[A-Za-z0-9\-_.~+/=]{20,}"'
    }
)

# File extensions to scan for committed secrets
$sourceExtensions = @("*.tf", "*.yml", "*.yaml", "*.json", "*.ps1", "*.sh", "*.cfg", "*.ini", "*.conf")

$sourceFiles = @()
foreach ($ext in $sourceExtensions) {
    $sourceFiles += Get-ChildItem -Path $Phase2Path -Filter $ext -Recurse -File |
        Where-Object {
            $_.FullName -notmatch '\.terraform' -and
            $_.FullName -notmatch 'node_modules' -and
            $_.FullName -notmatch '\.tfstate' -and
            $_.Name -notmatch '\.example' -and
            $_.Name -notmatch '\.sample'
        }
}

if ($sourceFiles.Count -eq 0) {
    Write-Host "WARNING: No source files found to scan" -ForegroundColor Yellow
}
else {
    Write-Host "Found $($sourceFiles.Count) source file(s) to scan" -ForegroundColor Gray

    foreach ($file in $sourceFiles) {
        $relativePath = $file.FullName.Replace($Phase2Path, "phase 2")
        $lines = Get-Content -Path $file.FullName

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $trimmedLine = $line.TrimStart()

            # Skip comments
            if ($trimmedLine.StartsWith("#") -or $trimmedLine.StartsWith("//") -or $trimmedLine.StartsWith("/*")) {
                continue
            }

            # Skip lines that are variable declarations with sensitive = true (these are definitions, not values)
            if ($trimmedLine -match '^\s*sensitive\s*=\s*true') {
                continue
            }

            # Skip lines referencing environment variables or GitHub secrets
            if ($line -match '\$\{\{\s*secrets\.' -or $line -match 'TF_VAR_' -or $line -match '\$env:') {
                continue
            }

            # Skip description and error_message attributes
            if ($trimmedLine -match '^\s*(description|error_message)\s*=') {
                continue
            }

            # Skip variable validation condition lines
            if ($trimmedLine -match '^\s*condition\s*=') {
                continue
            }

            foreach ($patternDef in $committedSecretPatterns) {
                if ($line -match $patternDef.Pattern) {
                    $violations += [PSCustomObject]@{
                        Check       = "Secret in Source File"
                        File        = $relativePath
                        Line        = ($i + 1)
                        Detail      = "$($patternDef.Name) — actual secret values must not appear in committed files"
                        Severity    = "CRITICAL"
                    }
                }
            }
        }
    }
}

$check3Violations = $violations.Count - $check1Violations - $check2Violations
Write-Host "Check 3 complete: $check3Violations violation(s) found" -ForegroundColor $(if ($check3Violations -eq 0) { "Green" } else { "Red" })
Write-Host ""

# =============================================================================
# Report Results
# =============================================================================

Write-Host "=== Scan Results ===" -ForegroundColor Cyan
Write-Host ""

$totalViolations = $violations.Count

if ($totalViolations -eq 0) {
    Write-Host "PASSED: All sensitive value protection checks passed" -ForegroundColor Green
    Write-Host ""
    Write-Host "  - All sensitive outputs have 'sensitive = true' flag" -ForegroundColor Gray
    Write-Host "  - No secrets found in .tfvars files" -ForegroundColor Gray
    Write-Host "  - No actual secret values found in committed source files" -ForegroundColor Gray
    exit 0
}
else {
    Write-Host "FAILED: Found $totalViolations sensitive value protection violation(s)" -ForegroundColor Red
    Write-Host ""

    # Group by severity
    $criticalViolations = $violations | Where-Object { $_.Severity -eq "CRITICAL" }
    $highViolations = $violations | Where-Object { $_.Severity -eq "HIGH" }

    if ($criticalViolations.Count -gt 0) {
        Write-Host "  CRITICAL ($($criticalViolations.Count)):" -ForegroundColor Red
        foreach ($v in $criticalViolations) {
            Write-Host "    [$($v.Check)]" -ForegroundColor Red
            Write-Host "      File: $($v.File)" -ForegroundColor White
            Write-Host "      Line: $($v.Line)" -ForegroundColor White
            Write-Host "      Issue: $($v.Detail)" -ForegroundColor Gray
            Write-Host ""
        }
    }

    if ($highViolations.Count -gt 0) {
        Write-Host "  HIGH ($($highViolations.Count)):" -ForegroundColor Yellow
        foreach ($v in $highViolations) {
            Write-Host "    [$($v.Check)]" -ForegroundColor Yellow
            Write-Host "      File: $($v.File)" -ForegroundColor White
            Write-Host "      Line: $($v.Line)" -ForegroundColor White
            Write-Host "      Issue: $($v.Detail)" -ForegroundColor Gray
            Write-Host ""
        }
    }

    Write-Host "Resolution:" -ForegroundColor Yellow
    Write-Host "  - Outputs referencing sensitive data must include 'sensitive = true'" -ForegroundColor Yellow
    Write-Host "  - Secrets must be passed via TF_VAR_* environment variables, not .tfvars files" -ForegroundColor Yellow
    Write-Host "  - No actual secret values should appear in any committed source file" -ForegroundColor Yellow
    Write-Host "  - Requirements 12.2, 12.3: Variable validation and sensitive flag enforcement" -ForegroundColor Yellow
    exit 1
}
