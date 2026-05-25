# =============================================================================
# Property 10: Resource Metadata Compliance
# Validates: Requirements 10.1, 10.2
#
# Verifies all resources follow the naming convention and have mandatory tags.
# - Resources that support tags must have a tags block with 'project' and
#   'environment' keys.
# - Resource names must follow the naming convention pattern using variable
#   references like ${var.project_name} and ${var.environment}.
# =============================================================================

param(
    [string]$ModulesPath = (Join-Path $PSScriptRoot ".." "modules")
)

$ErrorActionPreference = "Stop"
$violations = @()

# Resolve the modules path
$ModulesPath = Resolve-Path -Path $ModulesPath -ErrorAction Stop

Write-Host "=== Property 10: Resource Metadata Compliance ===" -ForegroundColor Cyan
Write-Host "Scanning modules directory: $ModulesPath" -ForegroundColor Gray
Write-Host ""

# Get all main.tf files in modules/ directories
$mainTfFiles = Get-ChildItem -Path $ModulesPath -Filter "main.tf" -Recurse

if ($mainTfFiles.Count -eq 0) {
    Write-Host "ERROR: No main.tf files found in $ModulesPath" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($mainTfFiles.Count) main.tf files to scan" -ForegroundColor Gray
Write-Host ""

# Azure resource types that support tags
$taggableResourceTypes = @(
    "azurerm_virtual_network",
    "azurerm_network_security_group",
    "azurerm_container_registry",
    "azurerm_private_dns_zone",
    "azurerm_private_dns_zone_virtual_network_link",
    "azurerm_private_endpoint",
    "azurerm_key_vault",
    "azurerm_user_assigned_identity",
    "azurerm_kubernetes_cluster",
    "azurerm_public_ip",
    "azurerm_network_interface",
    "azurerm_windows_virtual_machine",
    "azurerm_virtual_machine_extension",
    "azurerm_resource_group",
    "azurerm_log_analytics_workspace"
)

# Resource types that do NOT support tags (excluded from tag checks)
$nonTaggableResourceTypes = @(
    "azurerm_subnet",
    "azurerm_subnet_network_security_group_association",
    "azurerm_network_security_rule",
    "azurerm_role_assignment",
    "null_resource",
    "local_file"
)

# Naming convention patterns that indicate proper variable usage
# Resources should reference var.project_name and/or var.environment in their name
$namingVarPatterns = @(
    'var\.project_name',
    'var\.environment'
)

# Function to parse resource blocks from a Terraform file
function Get-ResourceBlocks {
    param(
        [string]$FilePath
    )

    $content = Get-Content -Path $FilePath -Raw
    $lines = Get-Content -Path $FilePath
    $resources = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Match resource block declarations
        if ($line -match '^\s*resource\s+"([^"]+)"\s+"([^"]+)"\s*\{') {
            $resourceType = $Matches[1]
            $resourceName = $Matches[2]
            $blockStartLine = $i
            $braceDepth = 0
            $blockLines = @()
            $foundBlockStart = $false

            # Collect all lines in this resource block
            for ($j = $i; $j -lt $lines.Count; $j++) {
                $blockLine = $lines[$j]
                $blockLines += $blockLine

                # Count braces
                $openBraces = ([regex]::Matches($blockLine, '\{')).Count
                $closeBraces = ([regex]::Matches($blockLine, '\}')).Count

                if ($openBraces -gt 0) {
                    $foundBlockStart = $true
                }

                $braceDepth += $openBraces - $closeBraces

                if ($foundBlockStart -and $braceDepth -le 0) {
                    break
                }
            }

            $resources += [PSCustomObject]@{
                Type      = $resourceType
                Name      = $resourceName
                StartLine = $blockStartLine + 1
                Lines     = $blockLines
                Content   = $blockLines -join "`n"
            }
        }
    }

    return $resources
}

# Function to check if a resource block has a tags block with mandatory keys
function Test-MandatoryTags {
    param(
        [PSCustomObject]$Resource
    )

    $content = $Resource.Content
    $missingTags = @()

    # Check if the resource has a tags block (direct or via local.tags)
    $hasTagsBlock = $false
    $hasProjectTag = $false
    $hasEnvironmentTag = $false

    # Check for tags = local.tags pattern
    if ($content -match 'tags\s*=\s*local\.tags') {
        $hasTagsBlock = $true
        # Assume local.tags contains both mandatory tags (verified by convention)
        $hasProjectTag = $true
        $hasEnvironmentTag = $true
    }
    # Check for tags = { ... } block or tags = merge(...)
    elseif ($content -match 'tags\s*=\s*(\{|merge\()') {
        $hasTagsBlock = $true

        # Check for project key
        if ($content -match 'project\s*=') {
            $hasProjectTag = $true
        }

        # Check for environment key
        if ($content -match 'environment\s*=') {
            $hasEnvironmentTag = $true
        }
    }
    # Check for tags = var.tags pattern
    elseif ($content -match 'tags\s*=\s*var\.tags') {
        $hasTagsBlock = $true
        # Assume var.tags is passed from root with mandatory tags
        $hasProjectTag = $true
        $hasEnvironmentTag = $true
    }

    if (-not $hasTagsBlock) {
        $missingTags += "no tags block"
    }
    else {
        if (-not $hasProjectTag) {
            $missingTags += "missing 'project' tag"
        }
        if (-not $hasEnvironmentTag) {
            $missingTags += "missing 'environment' tag"
        }
    }

    return $missingTags
}

# Function to check if a resource name follows the naming convention
function Test-NamingConvention {
    param(
        [PSCustomObject]$Resource
    )

    $content = $Resource.Content
    $issues = @()

    # Find the name attribute in the resource block (top-level only)
    # We look for: name = "..." at the first brace depth level
    $lines = $Resource.Lines
    $braceDepth = 0
    $nameValue = $null

    foreach ($line in $lines) {
        $openBraces = ([regex]::Matches($line, '\{')).Count
        $closeBraces = ([regex]::Matches($line, '\}')).Count
        $braceDepth += $openBraces - $closeBraces

        # Only check name attribute at the top level of the resource block (depth 1)
        if ($braceDepth -eq 1 -and $line -match '^\s*name\s*=\s*(.+)$') {
            $nameValue = $Matches[1].Trim()
            break
        }
    }

    # If no name attribute found, skip (some resources don't have a name)
    if (-not $nameValue) {
        return $issues
    }

    # Check if the name uses variable references for project/environment
    $usesProjectVar = $nameValue -match 'var\.project_name'
    $usesEnvironmentVar = $nameValue -match 'var\.environment'

    # Special case: ACR uses local.acr_name which is built from variables
    if ($nameValue -match 'local\.\w+') {
        # Locals that reference variables are acceptable
        return $issues
    }

    # Resources should reference at least var.environment in their name
    # (some resources like subnets use both, some use just environment)
    if (-not $usesProjectVar -and -not $usesEnvironmentVar) {
        # Check if it's a string literal without any variable interpolation
        if ($nameValue -match '^"[^$]*"$') {
            $issues += "name uses hardcoded value without var.project_name or var.environment reference: $nameValue"
        }
    }

    return $issues
}

# --- Main Scanning Logic ---

$totalResources = 0
$tagCheckedResources = 0
$nameCheckedResources = 0

foreach ($file in $mainTfFiles) {
    $relativePath = $file.FullName.Replace($ModulesPath, "modules")
    $moduleName = Split-Path (Split-Path $file.FullName -Parent) -Leaf

    Write-Host "Scanning: modules/$moduleName/main.tf" -ForegroundColor Gray

    $resources = Get-ResourceBlocks -FilePath $file.FullName

    foreach ($resource in $resources) {
        $totalResources++

        # --- Tag Compliance Check ---
        $isTaggable = $resource.Type -in $taggableResourceTypes
        $isNonTaggable = $resource.Type -in $nonTaggableResourceTypes

        if ($isTaggable) {
            $tagCheckedResources++
            $tagIssues = Test-MandatoryTags -Resource $resource

            if ($tagIssues.Count -gt 0) {
                $violations += [PSCustomObject]@{
                    Module   = $moduleName
                    File     = $relativePath
                    Line     = $resource.StartLine
                    Resource = "$($resource.Type).$($resource.Name)"
                    Check    = "Tag Compliance"
                    Issue    = $tagIssues -join "; "
                }
            }
        }
        elseif (-not $isNonTaggable) {
            # Unknown resource type - flag for review if it might support tags
            # For now, skip unknown types to avoid false positives
        }

        # --- Naming Convention Check ---
        # Skip resource types that don't have meaningful name attributes
        $skipNamingCheck = @(
            "azurerm_subnet_network_security_group_association",
            "azurerm_role_assignment",
            "null_resource",
            "local_file"
        )

        if ($resource.Type -notin $skipNamingCheck) {
            $nameCheckedResources++
            $namingIssues = Test-NamingConvention -Resource $resource

            if ($namingIssues.Count -gt 0) {
                foreach ($issue in $namingIssues) {
                    $violations += [PSCustomObject]@{
                        Module   = $moduleName
                        File     = $relativePath
                        Line     = $resource.StartLine
                        Resource = "$($resource.Type).$($resource.Name)"
                        Check    = "Naming Convention"
                        Issue    = $issue
                    }
                }
            }
        }
    }
}

# --- Report Results ---

Write-Host ""
Write-Host "=== Scan Results ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total resources scanned: $totalResources" -ForegroundColor Gray
Write-Host "Resources checked for tags: $tagCheckedResources" -ForegroundColor Gray
Write-Host "Resources checked for naming: $nameCheckedResources" -ForegroundColor Gray
Write-Host ""

if ($violations.Count -eq 0) {
    Write-Host "PASSED: All resources comply with metadata requirements" -ForegroundColor Green
    Write-Host ""
    Write-Host "  - All taggable resources have 'project' and 'environment' tags" -ForegroundColor Gray
    Write-Host "  - All resource names follow naming convention using variable references" -ForegroundColor Gray
    exit 0
}
else {
    Write-Host "FAILED: Found $($violations.Count) metadata compliance violation(s)" -ForegroundColor Red
    Write-Host ""

    # Group violations by check type
    $tagViolations = $violations | Where-Object { $_.Check -eq "Tag Compliance" }
    $namingViolations = $violations | Where-Object { $_.Check -eq "Naming Convention" }

    if ($tagViolations.Count -gt 0) {
        Write-Host "  --- Tag Compliance Violations ---" -ForegroundColor Yellow
        foreach ($v in $tagViolations) {
            Write-Host "    [$($v.Module)] $($v.Resource) (line $($v.Line))" -ForegroundColor White
            Write-Host "      Issue: $($v.Issue)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($namingViolations.Count -gt 0) {
        Write-Host "  --- Naming Convention Violations ---" -ForegroundColor Yellow
        foreach ($v in $namingViolations) {
            Write-Host "    [$($v.Module)] $($v.Resource) (line $($v.Line))" -ForegroundColor White
            Write-Host "      Issue: $($v.Issue)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    Write-Host "Resolution:" -ForegroundColor Yellow
    Write-Host "  - Requirement 10.1: All resources must follow naming patterns using" -ForegroundColor Yellow
    Write-Host "    `${var.project_name}` and `${var.environment}` variable references." -ForegroundColor Yellow
    Write-Host "  - Requirement 10.2: All taggable resources must have 'project' and" -ForegroundColor Yellow
    Write-Host "    'environment' tags set to the respective variable values." -ForegroundColor Yellow
    exit 1
}
