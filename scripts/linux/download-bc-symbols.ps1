#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Download Business Central symbol packages via developer endpoint

.DESCRIPTION
    Downloads BC symbol packages (.app files) from the BC container's developer endpoint.
    This approach mirrors BcContainerHelper's Compile-AppInNavContainer.ps1 symbol download logic
    and is compatible with Linux containers.

.PARAMETER BaseUrl
    The base URL of the BC container developer endpoint (default: "http://localhost:7049/BC")

.PARAMETER Tenant
    The tenant name (default: "default")

.PARAMETER Username
    Username for authentication (default: "admin")

.PARAMETER Password
    Password for authentication (default: "Admin123!")
    Note: Using String type for compatibility with BC container default credentials

.PARAMETER SymbolsFolder
    Destination folder for downloaded symbol packages (default: ".alpackages")

.PARAMETER BCVersion
    BC version number for tracking purposes (optional)

.EXAMPLE
    pwsh ./download-bc-symbols.ps1 -BaseUrl "http://localhost:7049/BC"

.NOTES
    This script uses the BC developer endpoint (/dev/packages) to download symbol packages.
    Based on BcContainerHelper's Compile-AppInNavContainer.ps1 symbol download logic.
    Compatible with Linux containers and GitHub Actions runners.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BaseUrl = "http://localhost:7049/BC",

    [Parameter(Mandatory=$false)]
    [string]$Tenant = "default",

    [Parameter(Mandatory=$false)]
    [string]$Username = "admin",

    [Parameter(Mandatory=$false)]
    [string]$Password = "Admin123!",

    [Parameter(Mandatory=$false)]
    [string]$SymbolsFolder = ".alpackages",

    [Parameter(Mandatory=$false)]
    [string]$BCVersion = ""
)

# Enable strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$StartTime = Get-Date

Write-Host "=== BC Symbol Package Download via Developer Endpoint ===" -ForegroundColor Cyan
Write-Host "Developer Endpoint: $BaseUrl" -ForegroundColor Gray
Write-Host "Tenant: $Tenant" -ForegroundColor Gray
Write-Host "Symbols Folder: $SymbolsFolder" -ForegroundColor Gray
Write-Host ""

# Create symbols folder
if (!(Test-Path $SymbolsFolder -PathType Container)) {
    New-Item -Path $SymbolsFolder -ItemType Directory | Out-Null
    Write-Host "Created symbols folder: $SymbolsFolder" -ForegroundColor Green
}

# Create credentials
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))

# Headers for API requests
$Headers = @{
    "Authorization" = "Basic $base64AuthInfo"
}

# Define dependencies to download
# Based on app.json and testApp.json dependencies for The Library project
# Using version 26.0.0.0 to match platform/application version from app.json
$dependencies = @(
    @{ Publisher = "Microsoft"; Name = "System"; Version = "26.0.0.0"; AppId = "8874ed3a-0643-4247-9ced-7a7002f7135d" }
    @{ Publisher = "Microsoft"; Name = "System Application"; Version = "26.0.0.0"; AppId = "63ca2fa4-4f03-4f2b-a480-172fef340d3f" }
    @{ Publisher = "Microsoft"; Name = "Business Foundation"; Version = "26.0.0.0"; AppId = "f3552374-a1f2-4356-848e-196002525837" }
    @{ Publisher = "Microsoft"; Name = "Base Application"; Version = "26.0.0.0"; AppId = "437dbf0e-84ff-417a-965d-ed2bb9650972" }
    @{ Publisher = "Microsoft"; Name = "Application"; Version = "26.0.0.0"; AppId = "c1335042-3002-4257-bf8a-75c898ccb1b8" }
    # Test dependencies from TestApp/app.json
    @{ Publisher = "Microsoft"; Name = "Any"; Version = "26.0.0.0"; AppId = "e7320ebb-08b3-4406-b1ec-b4927d3e280b" }
    @{ Publisher = "Microsoft"; Name = "Library Assert"; Version = "26.0.0.0"; AppId = "dd0be2ea-f733-4d65-bb34-a28f4624fb14" }
    @{ Publisher = "Microsoft"; Name = "Library Variable Storage"; Version = "26.0.0.0"; AppId = "5095f467-0a01-4b99-99d1-9ff1237d286f" }
    @{ Publisher = "Microsoft"; Name = "Test Runner"; Version = "26.0.0.0"; AppId = "23de40a6-dfe8-4f80-80db-d70f83ce8caf" }
)

Write-Host "Downloading symbol packages..." -ForegroundColor Yellow
Write-Host ""

$downloadedCount = 0
$skippedCount = 0
$failedCount = 0

foreach ($dep in $dependencies) {
    $publisher = [uri]::EscapeDataString($dep.Publisher)
    $name = [uri]::EscapeDataString($dep.Name)
    $version = $dep.Version
    $appId = $dep.AppId

    # Create filename for the symbol package
    $symbolsName = "$($dep.Publisher)_$($dep.Name)_$($version).app" -replace '[\\/:*?"<>|]', '_'
    $symbolsFile = Join-Path $SymbolsFolder $symbolsName

    # Skip if already exists
    if (Test-Path $symbolsFile) {
        Write-Host "  ↷ $symbolsName (already exists)" -ForegroundColor DarkGray
        $skippedCount++
        continue
    }

    # Construct developer endpoint URL
    # Using publisher&appName&versionText&appId&tenant format (matches BcContainerHelper pattern)
    $url = "$BaseUrl/dev/packages?publisher=$publisher&appName=$name&versionText=$version&appId=$appId&tenant=$Tenant"

    Write-Host "  ↓ $symbolsName" -ForegroundColor Cyan
    Write-Host "    URL: $url" -ForegroundColor DarkGray

    try {
        # Download using Invoke-WebRequest for better control
        Invoke-WebRequest -Uri $url `
            -Method Get `
            -Headers $Headers `
            -OutFile $symbolsFile `
            -UseBasicParsing `
            -AllowUnencryptedAuthentication `
            -TimeoutSec 300 | Out-Null

        if (Test-Path $symbolsFile) {
            $fileSize = (Get-Item $symbolsFile).Length
            Write-Host "    ✓ Downloaded ($([Math]::Round($fileSize / 1KB, 2)) KB)" -ForegroundColor Green
            $downloadedCount++
        } else {
            Write-Host "    ✗ Download failed - file not created" -ForegroundColor Red
            $failedCount++
        }
    }
    catch {
        Write-Host "    ✗ Download failed: $($_.Exception.Message)" -ForegroundColor Red

        # Try fallback URL without appId (for older BC versions)
        try {
            Write-Host "    ↻ Retrying without appId parameter..." -ForegroundColor Yellow
            $legacyUrl = "$BaseUrl/dev/packages?publisher=$publisher&appName=$name&versionText=$version&tenant=$Tenant"
            Write-Host "    URL: $legacyUrl" -ForegroundColor DarkGray

            Invoke-WebRequest -Uri $legacyUrl `
                -Method Get `
                -Headers $Headers `
                -OutFile $symbolsFile `
                -UseBasicParsing `
                -AllowUnencryptedAuthentication `
                -TimeoutSec 300 | Out-Null

            if (Test-Path $symbolsFile) {
                $fileSize = (Get-Item $symbolsFile).Length
                Write-Host "    ✓ Downloaded ($([Math]::Round($fileSize / 1KB, 2)) KB)" -ForegroundColor Green
                $downloadedCount++
            } else {
                Write-Host "    ✗ Download failed - file not created" -ForegroundColor Red
                $failedCount++
            }
        }
        catch {
            Write-Host "    ✗ Fallback also failed: $($_.Exception.Message)" -ForegroundColor Red
            $failedCount++
        }
    }
}

$EndTime = Get-Date
$Duration = ($EndTime - $StartTime).TotalSeconds

Write-Host ""
Write-Host "=== Download Summary ===" -ForegroundColor Cyan
Write-Host "Downloaded: $downloadedCount" -ForegroundColor Green
Write-Host "Skipped: $skippedCount" -ForegroundColor DarkGray
Write-Host "Failed: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "Green" })
Write-Host "Duration: $([Math]::Round($Duration, 2)) seconds" -ForegroundColor Gray
Write-Host ""

# List downloaded symbols
if (Test-Path $SymbolsFolder) {
    $symbolFiles = Get-ChildItem -Path $SymbolsFolder -Filter "*.app"
    Write-Host "Symbol packages in $($SymbolsFolder):" -ForegroundColor Cyan
    $symbolFiles | ForEach-Object {
        $sizeKB = [Math]::Round($_.Length / 1KB, 2)
        Write-Host "  - $($_.Name) ($sizeKB KB)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Set GitHub Actions environment variables if running in GitHub Actions
if ($env:GITHUB_ENV) {
    $formattedDuration = "{0:F6}" -f $Duration
    Add-Content -Path $env:GITHUB_ENV -Value "SYSTEM_DOWNLOAD_DURATION=$formattedDuration"
    Add-Content -Path $env:GITHUB_ENV -Value "SYSTEM_EXTRACT_DURATION=0"
    Write-Host "GitHub Actions environment variables set" -ForegroundColor Green
}

if ($failedCount -gt 0) {
    Write-Host "=== WARNING: Some symbol downloads failed ===" -ForegroundColor Yellow
    Write-Host "Compilation may fail if required dependencies are missing" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify BC container is running: docker ps" -ForegroundColor Gray
    Write-Host "  2. Check developer endpoint is accessible: curl $BaseUrl/dev/packages" -ForegroundColor Gray
    Write-Host "  3. Verify credentials are correct" -ForegroundColor Gray
    Write-Host "  4. Check BC container logs: docker logs bcserver" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "=== Symbol Download Successful ===" -ForegroundColor Green
exit 0
