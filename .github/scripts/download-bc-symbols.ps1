#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Download Business Central symbol packages via developer endpoint

.DESCRIPTION
    Downloads BC symbol packages (.app files) from the BC container's developer endpoint.
    Reads app.json to determine required dependencies and recursively downloads propagated dependencies.
    This approach mirrors BcContainerHelper's Compile-AppInNavContainer.ps1 symbol download logic
    and is compatible with Linux containers.

.PARAMETER AppJsonPath
    Path to the app.json file (required)

.PARAMETER BaseUrl
    The base URL of the BC container developer endpoint (default: "http://localhost:7049/BC")

.PARAMETER Tenant
    The tenant name (default: "default")

.PARAMETER Username
    Username for authentication (required)

.PARAMETER SymbolsFolder
    Destination folder for downloaded symbol packages (default: ".alpackages")

.EXAMPLE
    $env:BC_PASSWORD = "Admin123!"
    pwsh ./download-bc-symbols.ps1 -AppJsonPath "./App/app.json" -Username "admin"

.EXAMPLE
    $env:BC_PASSWORD = "Admin123!"
    pwsh ./download-bc-symbols.ps1 -AppJsonPath "./TestApp/app.json" -BaseUrl "http://localhost:7049/BC" -Username "admin"

.NOTES
    This script uses the BC developer endpoint (/dev/packages) to download symbol packages.
    Based on BcContainerHelper's Compile-AppInNavContainer.ps1 symbol download logic.
    Compatible with Linux containers and GitHub Actions runners.

    Requires environment variable:
    - BC_PASSWORD: Business Central admin user password

    Dependencies are resolved from:
    - app.json "dependencies" array
    - app.json "platform" version -> System app
    - app.json "application" version -> Application app
    - Propagated dependencies from downloaded apps (recursive)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$AppJsonPath,

    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = "http://localhost:7049/BC",

    [Parameter(Mandatory = $false)]
    [string]$Tenant = "default",

    [Parameter(Mandatory = $true)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [string]$SymbolsFolder = ".alpackages"
)

# Enable strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get password from environment variable
if (-not $env:BC_PASSWORD) {
    Write-Host "ERROR: BC_PASSWORD environment variable not set" -ForegroundColor Red
    Write-Host "Set it with: `$env:BC_PASSWORD = 'YourPassword'" -ForegroundColor Yellow
    exit 1
}
$Password = $env:BC_PASSWORD

# Verify app.json exists
if (!(Test-Path $AppJsonPath)) {
    Write-Host "ERROR: app.json not found at: $AppJsonPath" -ForegroundColor Red
    exit 1
}

# Read and parse app.json
Write-Host "=== BC Symbol Package Download via Developer Endpoint ===" -ForegroundColor Cyan
Write-Host "App.json: $AppJsonPath" -ForegroundColor Gray
Write-Host "Developer Endpoint: $BaseUrl" -ForegroundColor Gray
Write-Host "Tenant: $Tenant" -ForegroundColor Gray
Write-Host "Symbols Folder: $SymbolsFolder" -ForegroundColor Gray
Write-Host ""

$appJson = Get-Content $AppJsonPath -Raw | ConvertFrom-Json
Write-Host "App: $($appJson.name) v$($appJson.version) by $($appJson.publisher)" -ForegroundColor Cyan
Write-Host "Platform: $($appJson.platform)" -ForegroundColor Gray
if ($appJson.PSObject.Properties.Name -contains "application") {
    Write-Host "Application: $($appJson.application)" -ForegroundColor Gray
}
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

# Track all dependencies to download (with deduplication by AppId)
$dependenciesToDownload = @{}
$downloadedApps = @{}

# Helper function to add dependency to download queue
function Add-DependencyToQueue {
    param(
        [string]$Publisher,
        [string]$Name,
        [string]$Version,
        [string]$AppId,
        [string]$Source
    )

    $key = $AppId.ToLower()
    if (!$dependenciesToDownload.ContainsKey($key) -and !$downloadedApps.ContainsKey($key)) {
        $dependenciesToDownload[$key] = @{
            Publisher = $Publisher
            Name      = $Name
            Version   = $Version
            AppId     = $AppId
            Source    = $Source
        }
        Write-Host "  + Queued: $Name v$Version (from $Source)" -ForegroundColor DarkGray
    }
}

# Helper function to download a single app
function Download-App {
    param(
        [hashtable]$Dependency
    )

    $publisher = [uri]::EscapeDataString($Dependency.Publisher)
    $name = [uri]::EscapeDataString($Dependency.Name)
    $version = $Dependency.Version
    $appId = $Dependency.AppId

    # Create filename for the symbol package
    $symbolsName = "$($Dependency.Publisher)_$($Dependency.Name)_$($version).app" -replace '[\\/:*?"<>|]', '_'
    $symbolsFile = Join-Path $SymbolsFolder $symbolsName

    # Skip if already exists
    if (Test-Path $symbolsFile) {
        Write-Host "  ↷ $symbolsName (already exists)" -ForegroundColor DarkGray
        return @{ Success = $true; Skipped = $true; FilePath = $symbolsFile }
    }

    # Construct developer endpoint URL
    $url = "$BaseUrl/dev/packages?publisher=$publisher&appName=$name&versionText=$version&appId=$appId&tenant=$Tenant"

    Write-Host "  ↓ $symbolsName" -ForegroundColor Cyan

    try {
        Write-Host "Sending request to $url"
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
            return @{ Success = $true; Skipped = $false; FilePath = $symbolsFile }
        }
        else {
            Write-Host "    ✗ Download failed - file not created" -ForegroundColor Red
            throw "File not created after download"
        }
    }
    catch {
        Write-Host "    ✗ Download failed: $($_.Exception.Message)" -ForegroundColor Red

        # Try fallback URL without appId
        try {
            Write-Host "    ↻ Retrying without appId parameter..." -ForegroundColor Yellow
            $legacyUrl = "$BaseUrl/dev/packages?publisher=$publisher&appName=$name&versionText=$version&tenant=$Tenant"

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
                return @{ Success = $true; Skipped = $false; FilePath = $symbolsFile }
            }
            else {
                Write-Host "    ✗ Fallback failed - file not created" -ForegroundColor Red
                throw "File not created after fallback download"
            }
        }
        catch {
            Write-Host "    ✗ Fallback also failed: $($_.Exception.Message)" -ForegroundColor Red
            return @{ Success = $false; Skipped = $false; Error = $_.Exception.Message }
        }
    }
}

# Helper function to extract propagated dependencies from an app file
function Get-PropagatedDependencies {
    param(
        [string]$AppFilePath,
        [string]$AppName
    )

    try {
        # Use AL tool to get package manifest
        $manifestJson = & al GetPackageManifest "$AppFilePath" 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ⚠ Could not read manifest from $AppName" -ForegroundColor Yellow
            return @()
        }

        $manifest = $manifestJson | ConvertFrom-Json

        # Check if this app propagates dependencies
        if ($manifest.PSObject.Properties.Name -contains "propagateDependencies" -and $manifest.propagateDependencies -eq $true) {
            Write-Host "    → $AppName propagates dependencies" -ForegroundColor Cyan

            $propagatedDeps = @()
            if ($manifest.PSObject.Properties.Name -contains "dependencies") {
                foreach ($dep in $manifest.dependencies) {
                    $propagatedDeps += @{
                        Publisher = $dep.publisher
                        Name      = $dep.name
                        Version   = $dep.version
                        AppId     = $dep.id
                    }
                }
            }
            return $propagatedDeps
        }

        return @()
    }
    catch {
        Write-Host "    ⚠ Error reading manifest from $($AppName): $($_.Exception.Message)" -ForegroundColor Yellow
        return @()
    }
}

Write-Host "Analyzing dependencies from app.json..." -ForegroundColor Yellow
Write-Host ""

# Add System app (from platform version)
if ($appJson.PSObject.Properties.Name -contains "platform" -and $appJson.platform) {
    Add-DependencyToQueue -Publisher "Microsoft" -Name "System" -Version $appJson.platform `
        -AppId "8874ed3a-0643-4247-9ced-7a7002f7135d" -Source "platform"
}

# Add Application app (from application version)
if ($appJson.PSObject.Properties.Name -contains "application" -and $appJson.application) {
    Add-DependencyToQueue -Publisher "Microsoft" -Name "Application" -Version $appJson.application `
        -AppId "c1335042-3002-4257-bf8a-75c898ccb1b8" -Source "application"
}

# Add explicit dependencies from app.json
if ($appJson.PSObject.Properties.Name -contains "dependencies" -and $appJson.dependencies) {
    foreach ($dep in $appJson.dependencies) {
        $depId = if ($dep.PSObject.Properties.Name -contains "id") { $dep.id } else { $dep.appId }
        $depVersion = if ($dep.PSObject.Properties.Name -contains "version") { $dep.version } else { "1.0.0.0" }

        Add-DependencyToQueue -Publisher $dep.publisher -Name $dep.name -Version $depVersion `
            -AppId $depId -Source "app.json dependencies"
    }
}

Write-Host ""
Write-Host "Downloading symbol packages..." -ForegroundColor Yellow
Write-Host ""

$downloadedCount = 0
$skippedCount = 0
$failedCount = 0

# Process dependencies queue (will grow as we discover propagated dependencies)
while ($dependenciesToDownload.Count -gt 0) {
    # Get next dependency to download
    $key = $dependenciesToDownload.Keys | Select-Object -First 1
    $dep = $dependenciesToDownload[$key]
    $dependenciesToDownload.Remove($key)

    # Download the app
    $result = Download-App -Dependency $dep

    if ($result.Success) {
        if ($result.Skipped) {
            $skippedCount++
        }
        else {
            $downloadedCount++
        }

        # Mark as downloaded
        $downloadedApps[$key] = $dep

        # Check for propagated dependencies
        if ($result.FilePath) {
            $propagatedDeps = Get-PropagatedDependencies -AppFilePath $result.FilePath -AppName $dep.Name

            foreach ($propDep in $propagatedDeps) {
                Add-DependencyToQueue -Publisher $propDep.Publisher -Name $propDep.Name `
                    -Version $propDep.Version -AppId $propDep.AppId `
                    -Source "propagated from $($dep.Name)"
            }
        }
    }
    else {
        $failedCount++
        Write-Host "  ⚠ WARNING: Failed to download $($dep.Name) v$($dep.Version)" -ForegroundColor Yellow
        Write-Host "    Error: $($result.Error)" -ForegroundColor Yellow
        Write-Host "    Continuing with remaining dependencies..." -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "=== Download Summary ===" -ForegroundColor Cyan
Write-Host "Downloaded: $downloadedCount" -ForegroundColor Green
Write-Host "Skipped: $skippedCount" -ForegroundColor DarkGray
Write-Host "Failed: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "Green" })
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

if ($failedCount -gt 0) {
    Write-Host "=== WARNING: Some symbol downloads failed ===" -ForegroundColor Yellow
    Write-Host "Downloaded: $downloadedCount | Skipped: $skippedCount | Failed: $failedCount" -ForegroundColor Yellow
    Write-Host "Compilation may fail if required dependencies are missing" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify BC container is running: docker ps" -ForegroundColor Gray
    Write-Host "  2. Check developer endpoint is accessible: curl $BaseUrl/dev/packages" -ForegroundColor Gray
    Write-Host "  3. Verify credentials are correct" -ForegroundColor Gray
    Write-Host "  4. Check BC container logs: docker logs bcserver" -ForegroundColor Gray
    Write-Host ""
}
else {
    Write-Host "=== Symbol Download Successful ===" -ForegroundColor Green
}

exit 0
