#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Import BC Test Toolkit apps into the BC container

.DESCRIPTION
    Syncs and installs Microsoft Test Toolkit apps from the BC container

.PARAMETER Verbose
    Show detailed logging output

.EXAMPLE
    ./import-test-toolkit.ps1
    ./import-test-toolkit.ps1 -Verbose
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "INSTALLING BC TEST TOOLKIT" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Push-Location bcdev-temp

try {
    # First, detect BC version from inside the container
    # Note: detect-bc-version.sh is provided by the BCDevOnLinux container setup
    Write-Host "Detecting BC version from container..." -ForegroundColor Yellow
    $bcVersionOutput = docker compose exec bc bash -c '/home/scripts/bc/detect-bc-version.sh 2>&1'
    
    # Extract just the version number (e.g., "260")
    $bcVersion = ($bcVersionOutput -split "`n" | Select-Object -Last 1).Trim()
    
    # Validate version format - must be 2-3 digits (e.g., "260", "270")
    if ([string]::IsNullOrWhiteSpace($bcVersion) -or $bcVersion -notmatch '^\d{2,3}$') {
        Write-Host "Failed to detect BC version. Output: $bcVersionOutput" -ForegroundColor Red
        Write-Host "Using default version 260" -ForegroundColor Yellow
        $bcVersion = "260"
    }
    
    Write-Host "Using BC version: $bcVersion" -ForegroundColor Green
    Write-Host ""

    # Create PowerShell script to run inside container through Wine
    # Note: This will run under Wine PowerShell, so we use Windows C:\ paths
    $containerScript = @"
# Import BC Management module
`$bcVersion = '$bcVersion'
`$modulePath = "C:\Program Files\Microsoft Dynamics NAV\`$bcVersion\Service\Management\Microsoft.Dynamics.Nav.Management.dll"
Write-Host "Loading NAV Management module from: `$modulePath"

# Test if the module path exists
if (-not (Test-Path `$modulePath)) {
    Write-Error "NAV Management DLL not found at: `$modulePath"
    Write-Host "Searching for alternative paths..."
    
    # Try to find any BC version directory
    try {
        `$navDir = "C:\Program Files\Microsoft Dynamics NAV"
        `$altPath = Get-ChildItem `$navDir -Attributes Directory -ErrorAction Stop | 
            Sort-Object Name -Descending | 
            Select-Object -First 1 | 
            ForEach-Object { Join-Path `$_.FullName "Service\Management\Microsoft.Dynamics.Nav.Management.dll" }
        
        if (`$altPath -and (Test-Path `$altPath)) {
            Write-Host "Found alternative path: `$altPath"
            `$modulePath = `$altPath
        } else {
            Write-Error "Could not find NAV Management DLL in any version directory"
            exit 1
        }
    }
    catch {
        Write-Error "Could not access Microsoft Dynamics NAV directory: `$_"
        exit 1
    }
}

Import-Module `$modulePath -ErrorAction Stop
Write-Host "Successfully loaded NAV Management module"

`$serverInstance = 'BC'
`$tenant = 'default'

Write-Host "Getting published test toolkit apps from server..."

# Get all published apps from the server
`$publishedApps = Get-NAVAppInfo -ServerInstance `$serverInstance | Where-Object {
    `$_.Publisher -eq 'Microsoft' -and
    (`$_.Name -like '*Test*' -or `$_.Name -like '*Performance Toolkit*')
}

if (`$publishedApps.Count -eq 0) {
    Write-Error "No published test toolkit apps found"
    exit 1
}

Write-Host "Found `$(`$publishedApps.Count) published test toolkit app(s)"

# Get tenant-specific app info to see what's installed
`$tenantApps = Get-NAVAppInfo -ServerInstance `$serverInstance -Tenant `$tenant -TenantSpecificProperties

# Define the installation order based on dependencies
`$orderedPatterns = @(
    'Permissions Mock',
    'Test Runner',
    'Any',
    'Library Assert',
    'Library Variable Storage',
    'System Application Test Library',
    'Business Foundation Test Libraries',
    'Application Test Library',
    'Tests-TestLibraries',
    'AI Test Toolkit'
)

`$installedCount = 0
`$skippedCount = 0
`$alreadyInstalledCount = 0

foreach (`$pattern in `$orderedPatterns) {
    `$matchingApps = `$publishedApps | Where-Object { `$_.Name -like "*`$pattern*" } | Sort-Object Name

    foreach (`$app in `$matchingApps) {
        # Skip SINGLESERVER tests
        if (`$app.Name -like "*SINGLESERVER*") {
            Write-Host "Skipping SINGLESERVER test: `$(`$app.Name)" -ForegroundColor Yellow
            `$skippedCount++
            continue
        }

        # Check if already installed
        `$tenantApp = `$tenantApps | Where-Object {
            `$_.AppId -eq `$app.AppId -and `$_.Version -eq `$app.Version
        }

        if (`$tenantApp -and `$tenantApp.IsInstalled) {
            Write-Host "Already installed: `$(`$app.Name) `$(`$app.Version)" -ForegroundColor Gray
            `$alreadyInstalledCount++
            continue
        }

        try {
            Write-Host "Syncing and installing: `$(`$app.Name) `$(`$app.Version)" -ForegroundColor Cyan

            # Sync the app if needed
            if (-not `$tenantApp -or `$tenantApp.SyncState -ne 'Synced') {
                Sync-NavApp -ServerInstance `$serverInstance ``
                           -Name `$app.Name ``
                           -Publisher `$app.Publisher ``
                           -Version `$app.Version ``
                           -Tenant `$tenant ``
                           -ErrorAction Stop
            }

            # Install the app
            Install-NavApp -ServerInstance `$serverInstance ``
                          -Name `$app.Name ``
                          -Publisher `$app.Publisher ``
                          -Version `$app.Version ``
                          -Tenant `$tenant ``
                          -ErrorAction Stop

            Write-Host "✓ Successfully installed: `$(`$app.Name)" -ForegroundColor Green
            `$installedCount++
        }
        catch {
            Write-Host "✗ Failed to install `$(`$app.Name): `$_" -ForegroundColor Red
            Write-Host "Continuing with next app..." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "========================================="
Write-Host "TEST TOOLKIT IMPORT SUMMARY"
Write-Host "========================================="
Write-Host "Newly installed: `$installedCount app(s)" -ForegroundColor Green
Write-Host "Already installed: `$alreadyInstalledCount app(s)" -ForegroundColor Gray
Write-Host "Skipped: `$skippedCount app(s)" -ForegroundColor Yellow
Write-Host ""

if (`$installedCount -eq 0 -and `$alreadyInstalledCount -eq 0) {
    Write-Error "No test toolkit apps were installed successfully"
    exit 1
}
"@

    Write-Host "Executing PowerShell script inside BC container..." -ForegroundColor Yellow
    Write-Host "This may take several minutes depending on the number of apps..." -ForegroundColor Yellow
    Write-Host ""

    # Write script to a temporary file in the container and execute it through Wine PowerShell
    # The NAV Management cmdlets must run under Wine because they call native Windows binaries
    $tempScriptPath = "/tmp/import-test-toolkit-$([guid]::NewGuid().ToString()).ps1"
    $output = docker compose exec bc bash -c "cat > '$tempScriptPath' << 'PSEOF'
$containerScript
PSEOF
wine powershell -ExecutionPolicy Bypass -File 'Z:$tempScriptPath'
rm -f '$tempScriptPath'
" 2>&1

    Write-Host $output
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Test toolkit import completed successfully!" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "✗ Test toolkit import failed" -ForegroundColor Red
        exit 1
    }
}
finally {
    Pop-Location
}
