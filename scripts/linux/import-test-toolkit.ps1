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
    # Create PowerShell script to run inside container
    $containerScript = @'
# Import BC Management module
Import-Module 'C:\Program Files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Management.dll' -ErrorAction Stop

$serverInstance = 'BC'
$tenant = 'default'

Write-Host "Getting published test toolkit apps from server..."

# Get all published apps from the server
$publishedApps = Get-NAVAppInfo -ServerInstance $serverInstance | Where-Object {
    $_.Publisher -eq 'Microsoft' -and
    ($_.Name -like '*Test*' -or $_.Name -like '*Performance Toolkit*')
}

if ($publishedApps.Count -eq 0) {
    Write-Error "No published test toolkit apps found"
    exit 1
}

Write-Host "Found $($publishedApps.Count) published test toolkit app(s)"

# Get tenant-specific app info to see what's installed
$tenantApps = Get-NAVAppInfo -ServerInstance $serverInstance -Tenant $tenant -TenantSpecificProperties

# Define the installation order based on dependencies
$orderedPatterns = @(
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

$installedCount = 0
$skippedCount = 0
$alreadyInstalledCount = 0

foreach ($pattern in $orderedPatterns) {
    $matchingApps = $publishedApps | Where-Object { $_.Name -like "*$pattern*" } | Sort-Object Name

    foreach ($app in $matchingApps) {
        # Skip SINGLESERVER tests
        if ($app.Name -like "*SINGLESERVER*") {
            Write-Host "Skipping SINGLESERVER test: $($app.Name)" -ForegroundColor Yellow
            $skippedCount++
            continue
        }

        # Check if already installed
        $tenantApp = $tenantApps | Where-Object {
            $_.AppId -eq $app.AppId -and $_.Version -eq $app.Version
        }

        if ($tenantApp -and $tenantApp.IsInstalled) {
            Write-Host "Already installed: $($app.Name) $($app.Version)" -ForegroundColor Gray
            $alreadyInstalledCount++
            continue
        }

        try {
            Write-Host "Syncing and installing: $($app.Name) $($app.Version)" -ForegroundColor Cyan

            # Sync the app if needed
            if (-not $tenantApp -or $tenantApp.SyncState -ne 'Synced') {
                Sync-NavApp -ServerInstance $serverInstance `
                           -Name $app.Name `
                           -Publisher $app.Publisher `
                           -Version $app.Version `
                           -Tenant $tenant `
                           -ErrorAction Stop
            }

            # Install the app
            Install-NavApp -ServerInstance $serverInstance `
                          -Name $app.Name `
                          -Publisher $app.Publisher `
                          -Version $app.Version `
                          -Tenant $tenant `
                          -ErrorAction Stop

            Write-Host "✓ Successfully installed: $($app.Name)" -ForegroundColor Green
            $installedCount++
        }
        catch {
            Write-Host "✗ Failed to install $($app.Name): $_" -ForegroundColor Red
            Write-Host "Continuing with next app..." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "========================================="
Write-Host "TEST TOOLKIT IMPORT SUMMARY"
Write-Host "========================================="
Write-Host "Newly installed: $installedCount app(s)" -ForegroundColor Green
Write-Host "Already installed: $alreadyInstalledCount app(s)" -ForegroundColor Gray
Write-Host "Skipped: $skippedCount app(s)" -ForegroundColor Yellow
Write-Host ""

if ($installedCount -eq 0 -and $alreadyInstalledCount -eq 0) {
    Write-Error "No test toolkit apps were installed successfully"
    exit 1
}
'@

    Write-Host "Executing PowerShell script inside BC container..." -ForegroundColor Yellow
    Write-Host "This may take several minutes depending on the number of apps..." -ForegroundColor Yellow
    Write-Host ""

    # Execute the PowerShell script inside the container
    $output = docker compose exec bc pwsh -Command $containerScript 2>&1

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
