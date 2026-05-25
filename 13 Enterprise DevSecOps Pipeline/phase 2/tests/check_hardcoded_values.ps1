# =============================================================================
# Property 8: Zero Hardcoded Values
# Validates: Requirements 8.4
#
# Scans all module .tf files for hardcoded environment names, CIDRs, or region
# names. Ensures all environment-varying configuration is parameterized through
# input variables with no literal values specific to a single environment.
# =============================================================================

param(
    [string]$ModulesPath = (Join-Path $PSScriptRoot ".." "modules")
)

$ErrorActionPreference = "Stop"
$violations = @()

# Resolve the modules path
$ModulesPath = Resolve-Path -Path $ModulesPath -ErrorAction Stop

Write-Host "=== Property 8: Zero Hardcoded Values ===" -ForegroundColor Cyan
Write-Host "Scanning modules directory: $ModulesPath" -ForegroundColor Gray
Write-Host ""

# Get all .tf files in modules/ directories
$tfFiles = Get-ChildItem -Path $ModulesPath -Filter "*.tf" -Recurse

if ($tfFiles.Count -eq 0) {
    Write-Host "ERROR: No .tf files found in $ModulesPath" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($tfFiles.Count) .tf files to scan" -ForegroundColor Gray
Write-Host ""

# Define patterns to detect hardcoded values
# Each pattern has: Name, Regex, Description
$hardcodedPatterns = @(
    @{
        Name        = "Hardcoded Environment Name"
        Pattern     = '=\s*"(dev|staging|prod|production|uat|test)"'
        Description = "Literal environment name found as an assigned value"
    },
    @{
        Name        = "Hardcoded CIDR (10.0.x.x)"
        Pattern     = '=\s*"10\.0\.\d{1,3}\.\d{1,3}/\d{1,2}"'
        Description = "Hardcoded 10.0.x.x CIDR block found as an assigned value"
    },
    @{
        Name        = "Hardcoded CIDR (172.16.x.x)"
        Pattern     = '=\s*"172\.16\.\d{1,3}\.\d{1,3}/\d{1,2}"'
        Description = "Hardcoded 172.16.x.x CIDR block found as an assigned value"
    },
    @{
        Name        = "Hardcoded CIDR (192.168.x.x)"
        Pattern     = '=\s*"192\.168\.\d{1,3}\.\d{1,3}/\d{1,2}"'
        Description = "Hardcoded 192.168.x.x CIDR block found as an assigned value"
    },
    @{
        Name        = "Hardcoded Azure Region"
        Pattern     = '=\s*"(southeastasia|eastus|eastus2|westus|westus2|westeurope|northeurope|centralus|australiaeast|japaneast|uksouth|canadacentral|brazilsouth|koreacentral|francecentral|germanywestcentral|norwayeast|swedencentral|switzerlandnorth)"'
        Description = "Hardcoded Azure region name found as an assigned value"
    },
    @{
        Name        = "Hardcoded CIDR in List"
        Pattern     = '\[\s*"10\.0\.\d{1,3}\.\d{1,3}/\d{1,2}"'
        Description = "Hardcoded CIDR block found in a list literal"
    }
)

foreach ($file in $tfFiles) {
    $relativePath = $file.FullName.Replace($ModulesPath, "modules")
    $lines = Get-Content -Path $file.FullName
    $inComment = $false
    $inVariableDefault = $false
    $braceDepth = 0
    $variableBraceStart = -1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNumber = $i + 1

        # Skip single-line comments
        $trimmedLine = $line.TrimStart()
        if ($trimmedLine.StartsWith("#") -or $trimmedLine.StartsWith("//")) {
            continue
        }

        # Track multi-line comments
        if ($trimmedLine -match '/\*') {
            $inComment = $true
        }
        if ($inComment) {
            if ($trimmedLine -match '\*/') {
                $inComment = $false
            }
            continue
        }

        # Remove inline comments from the line before pattern matching
        $lineWithoutComment = $line -replace '#.*$', '' -replace '//.*$', ''

        # Track if we are inside a variable "default" block
        # Detect variable block start
        if ($trimmedLine -match '^variable\s+"') {
            $inVariableDefault = $false
            $variableBraceStart = -1
        }

        # Detect "default" attribute within a variable block
        if ($trimmedLine -match '^\s*default\s*=') {
            $inVariableDefault = $true
            # If the default is on a single line, mark it and skip
            if ($trimmedLine -match '^\s*default\s*=\s*.+$' -and $trimmedLine -notmatch '\{$' -and $trimmedLine -notmatch '\[$') {
                $inVariableDefault = $false
                continue
            }
            continue
        }

        # If we're in a multi-line default value, skip until we exit
        if ($inVariableDefault) {
            # Simple heuristic: track braces/brackets to know when default ends
            $openBraces = ([regex]::Matches($line, '[\{\[]')).Count
            $closeBraces = ([regex]::Matches($line, '[\}\]]')).Count
            $braceDepth += $openBraces - $closeBraces
            if ($braceDepth -le 0) {
                $inVariableDefault = $false
                $braceDepth = 0
            }
            continue
        }

        # Skip description attributes (they commonly contain environment names as documentation)
        if ($trimmedLine -match '^\s*description\s*=') {
            continue
        }

        # Skip validation error_message attributes
        if ($trimmedLine -match '^\s*error_message\s*=') {
            continue
        }

        # Skip lines that are purely string interpolations using var references
        # e.g., name = "vnet-${var.project_name}-${var.environment}" is fine
        # We only flag lines where the hardcoded value is NOT inside a var reference

        # Check each pattern against the cleaned line
        foreach ($patternDef in $hardcodedPatterns) {
            if ($lineWithoutComment -match $patternDef.Pattern) {
                # Additional check: skip if the match is inside a variable interpolation context
                # e.g., "${var.environment}" should not trigger on "dev" inside var reference
                $matchValue = $Matches[1]

                # Skip if this line is a variable reference pattern like var.environment
                if ($lineWithoutComment -match 'var\.\w+') {
                    # Check if the matched value is part of a var interpolation
                    # If the entire value is a var reference, skip it
                    if ($lineWithoutComment -match "\`$\{var\.\w+\}") {
                        continue
                    }
                }

                # Skip role_definition_name values (these are Azure built-in role names, not environment config)
                if ($trimmedLine -match '^\s*role_definition_name\s*=') {
                    continue
                }

                # Skip provider version constraints
                if ($trimmedLine -match '^\s*version\s*=\s*"~>') {
                    continue
                }

                $violations += [PSCustomObject]@{
                    File        = $relativePath
                    Line        = $lineNumber
                    Pattern     = $patternDef.Name
                    Content     = $line.Trim()
                    Description = $patternDef.Description
                }
            }
        }
    }
}

# Report results
Write-Host "=== Scan Results ===" -ForegroundColor Cyan
Write-Host ""

if ($violations.Count -eq 0) {
    Write-Host "PASSED: No hardcoded values detected in module .tf files" -ForegroundColor Green
    Write-Host ""
    Write-Host "All environment-varying configuration is properly parameterized." -ForegroundColor Gray
    exit 0
}
else {
    Write-Host "FAILED: Found $($violations.Count) hardcoded value(s) in module .tf files" -ForegroundColor Red
    Write-Host ""

    foreach ($violation in $violations) {
        Write-Host "  [$($violation.Pattern)]" -ForegroundColor Yellow
        Write-Host "    File: $($violation.File)" -ForegroundColor White
        Write-Host "    Line: $($violation.Line)" -ForegroundColor White
        Write-Host "    Content: $($violation.Content)" -ForegroundColor Gray
        Write-Host "    Issue: $($violation.Description)" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "Resolution: Replace hardcoded values with variable references (var.<name>)" -ForegroundColor Yellow
    Write-Host "Requirement 8.4 states: No literal values specific to a single environment" -ForegroundColor Yellow
    Write-Host "shall appear in .tf source files outside of variable default attributes." -ForegroundColor Yellow
    exit 1
}
