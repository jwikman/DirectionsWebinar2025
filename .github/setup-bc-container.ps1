#Requires -Modules BcContainerHelper

<#
.SYNOPSIS
    Sets up a Docker container with Business Central and installs The Library apps
.DESCRIPTION
    This script uses BcContainerHelper to create a BC container, compile and publish
    The Library main app and test app, and install all necessary test libraries.
.PARAMETER containerName
    Name for the BC container (default: "TheLibrary")
.PARAMETER bcVersion
    Business Central version to use (default: "27" for BC 2025)
.PARAMETER licenseFile
    Path to BC license file (optional, uses developer license if not provided)
.PARAMETER memoryLimit
    Memory limit for container in GB (default: "8G")
.PARAMETER useTraefik
    Use Traefik for container routing (default: $false)
.EXAMPLE
    .\setup-bc-container.ps1
    .\setup-bc-container.ps1 -containerName "MyLibrary" -bcVersion "26"
    .\setup-bc-container.ps1 -licenseFile "C:\temp\license.flf"
#>

[CmdletBinding()]
param(
    [string]$containerName = "bcserver",
    [string]$bcVersion = "27",
    [string]$licenseFile = "",
    [string]$memoryLimit = "8G",
    [switch]$useTraefik = $false
)

$ErrorActionPreference = "Stop"

Write-Host "Setting up Business Central container for The Library project..." -ForegroundColor Green

# Ensure BcContainerHelper is available
if (!(Get-Module -Name BcContainerHelper -ListAvailable)) {
    Write-Host "Installing BcContainerHelper module..." -ForegroundColor Yellow
    Install-Module -Name BcContainerHelper -Scope CurrentUser -Force -AllowClobber
}

Import-Module -Name BcContainerHelper -DisableNameChecking -Force

# Disable telemetry
$bcContainerHelperConfig.MicrosoftTelemetryConnectionString = ""

# Project paths
$projectRoot = Split-Path -Parent $PSScriptRoot
$appFolder = Join-Path $projectRoot "App"
$testAppFolder = Join-Path $projectRoot "TestApp"
$tempFolder = Join-Path $PSScriptRoot ".tmp"

# Ensure temp folder exists
if (!(Test-Path -Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
}

# Verify app folders exist
if (!(Test-Path -Path $appFolder)) {
    throw "App folder not found: $appFolder"
}
if (!(Test-Path -Path $testAppFolder)) {
    throw "TestApp folder not found: $testAppFolder"
}

# Read app manifests
$appManifest = Get-Content (Join-Path $appFolder "app.json") -Encoding UTF8 | ConvertFrom-Json
$testAppManifest = Get-Content (Join-Path $testAppFolder "app.json") -Encoding UTF8 | ConvertFrom-Json

Write-Host "Main App: $($appManifest.name) v$($appManifest.version)" -ForegroundColor Cyan
Write-Host "Test App: $($testAppManifest.name) v$($testAppManifest.version)" -ForegroundColor Cyan

# Remove existing container if it exists
if ($containerName -in (Get-BcContainers)) {
    Write-Host "Removing existing container '$containerName'..." -ForegroundColor Yellow
    Remove-BcContainer -containerName $containerName -Force
}

# Container parameters
$containerParameters = @{
    "containerName" = $containerName
    "imageName" = ""  # Will be set by BcContainerHelper
    "accept_eula" = $true
    "Isolation" = "process"
    "memoryLimit" = $memoryLimit
    "auth" = "UserPassword"
    "Credential" = (New-Object System.Management.Automation.PSCredential("admin", (ConvertTo-SecureString "P@ssword1" -AsPlainText -Force)))
    "updateHosts" = $true
    "usessl" = $false
    "enableTaskScheduler" = $false
}

# Add license file if provided
if ($licenseFile -and (Test-Path $licenseFile)) {
    $containerParameters["licenseFile"] = $licenseFile
    Write-Host "Using license file: $licenseFile" -ForegroundColor Green
} else {
    Write-Host "Using developer license (container will expire after 90 days)" -ForegroundColor Yellow
}

# Add Traefik support if requested
if ($useTraefik) {
    $containerParameters["useTraefik"] = $true
    $containerParameters["PublishPorts"] = @()
} else {
    $containerParameters["PublishPorts"] = @(80, 443, 7046, 7047, 7048, 7049, 8080)
}

# Get the latest BC image for the specified version
Write-Host "Getting Business Central artifacts for version $bcVersion..." -ForegroundColor Yellow
$artifactUrl = Get-BcArtifactUrl -version $bcVersion -country "us" -select "Latest"
Write-Host "Using artifact URL: $artifactUrl" -ForegroundColor Cyan

# Create the container
Write-Host "Creating Business Central container '$containerName'..." -ForegroundColor Yellow
$containerParameters["artifactUrl"] = $artifactUrl

try {
    New-BcContainer @containerParameters

    # Wait for container to be ready
    Write-Host "Waiting for container to be fully ready..." -ForegroundColor Yellow
    Wait-BcContainerReady -containerName $containerName -timeout 600

    # Install test libraries first (required by TestApp)
    Write-Host "Installing Microsoft test libraries..." -ForegroundColor Yellow
    $testLibraries = @(
        "Microsoft_Library Assert_27.0.0.0.app",
        "Microsoft_Any_27.0.0.0.app",
        "Microsoft_Test Runner_27.0.0.0.app",
        "Microsoft_Library Variable Storage_27.0.0.0.app"
    )

    foreach ($testLib in $testLibraries) {
        $testLibPath = Join-Path $testAppFolder ".alpackages" $testLib
        if (Test-Path $testLibPath) {
            Write-Host "Installing $testLib..." -ForegroundColor Cyan
            Publish-BcContainerApp -containerName $containerName -appFile $testLibPath -skipVerification -install
        } else {
            Write-Warning "Test library not found: $testLibPath"
        }
    }

    # Compile and publish main app
    Write-Host "Compiling and publishing main app..." -ForegroundColor Yellow
    $mainAppFile = Join-Path $tempFolder "$($appManifest.publisher)_$($appManifest.name)_$($appManifest.version).app"

    if (Test-Path $mainAppFile) {
        Write-Host "Publishing main app: $($appManifest.name)" -ForegroundColor Cyan
        Publish-BcContainerApp -containerName $containerName -appFile $mainAppFile -skipVerification -install -sync
    } else {
        Write-Warning "Main app file not found: $mainAppFile"
        Write-Host "Run compilation script first: .\.github\.tmp\compile-app.ps1" -ForegroundColor Yellow
    }

    # Compile and publish test app
    Write-Host "Compiling and publishing test app..." -ForegroundColor Yellow
    $testAppFile = Join-Path $tempFolder "$($testAppManifest.publisher)_$($testAppManifest.name)_$($testAppManifest.version).app"

    if (Test-Path $testAppFile) {
        Write-Host "Publishing test app: $($testAppManifest.name)" -ForegroundColor Cyan
        Publish-BcContainerApp -containerName $containerName -appFile $testAppFile -skipVerification -install -sync
    } else {
        Write-Warning "Test app file not found: $testAppFile"
        Write-Host "Run compilation script first: .\.github\.tmp\compile-testapp.ps1" -ForegroundColor Yellow
    }

    # Get container information
    $containerInfo = Get-BcContainerNavVersion -containerName $containerName
    $webclientUrl = Get-BcContainerServerUrl -containerName $containerName

    Write-Host ""
    Write-Host "✅ Business Central container setup completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Container Information:" -ForegroundColor White
    Write-Host "  Name: $containerName" -ForegroundColor Cyan
    Write-Host "  Version: $($containerInfo.Version)" -ForegroundColor Cyan
    Write-Host "  Build: $($containerInfo.Build)" -ForegroundColor Cyan
    Write-Host "  Web Client: $webclientUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Credentials:" -ForegroundColor White
    Write-Host "  Username: admin" -ForegroundColor Cyan
    Write-Host "  Password: P@ssword1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Installed Apps:" -ForegroundColor White
    Write-Host "  ✓ $($appManifest.name) v$($appManifest.version)" -ForegroundColor Green
    Write-Host "  ✓ $($testAppManifest.name) v$($testAppManifest.version)" -ForegroundColor Green
    Write-Host "  ✓ Microsoft test libraries" -ForegroundColor Green
    Write-Host ""
    Write-Host "To run tests, use:" -ForegroundColor Yellow
    Write-Host "  Run-TestsInBcContainer -containerName '$containerName'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To stop the container:" -ForegroundColor Yellow
    Write-Host "  Stop-BcContainer -containerName '$containerName'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To remove the container:" -ForegroundColor Yellow
    Write-Host "  Remove-BcContainer -containerName '$containerName'" -ForegroundColor Cyan

} catch {
    Write-Error "Failed to create or configure container: $($_.Exception.Message)"

    # Clean up on failure
    if ($containerName -in (Get-BcContainers)) {
        Write-Host "Cleaning up failed container..." -ForegroundColor Yellow
        Remove-BcContainer -containerName $containerName -Force
    }

    throw
}