<#
.SYNOPSIS
    Linux-compatible version of BC container setup using BcContainerHelper
.DESCRIPTION
    This script uses BcContainerHelper's standard approach with minimal workarounds
    for Linux compatibility issues. Falls back gracefully when Windows-specific
    functions fail.
.PARAMETER containerName
    Name for the BC container (default: "bcserver")
.PARAMETER bcVersion
    Business Central version to use (default: "27" for BC 2025)
.PARAMETER licenseFile
    Path to BC license file (optional, uses developer license if not provided)
.PARAMETER memoryLimit
    Memory limit for container (default: "8G")
.PARAMETER skipContainer
    Skip container creation and only prepare compilation environment
.EXAMPLE
    .\setup-bc-container-linux.ps1
    .\setup-bc-container-linux.ps1 -containerName "MyLibrary" -bcVersion "26"
    .\setup-bc-container-linux.ps1 -skipContainer
#>

[CmdletBinding()]
param(
    [string]$containerName = "bcserver",
    [string]$bcVersion = "27",
    [string]$licenseFile = "",
    [string]$memoryLimit = "8G",
    [switch]$skipContainer = $false
)

$ErrorActionPreference = "Stop"

Write-Host "Setting up Business Central container using BcContainerHelper..." -ForegroundColor Green

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

if ($skipContainer) {
    Write-Host "Container setup skipped (-skipContainer specified)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "✅ Development environment prepared for compilation only." -ForegroundColor Green
    Write-Host ""
    Write-Host "Available compilation scripts:" -ForegroundColor White
    Write-Host "  Main App:  .\.github\.tmp\compile-app.ps1" -ForegroundColor Cyan
    Write-Host "  Test App:  .\.github\.tmp\compile-testapp.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To compile both apps:" -ForegroundColor White
    Write-Host "  pwsh ./.github/.tmp/compile-app.ps1" -ForegroundColor Cyan
    Write-Host "  pwsh ./.github/.tmp/compile-testapp.ps1" -ForegroundColor Cyan
    return
}

# Try to use BcContainerHelper - install and import if needed
Write-Host "Setting up BcContainerHelper..." -ForegroundColor Yellow
try {
    if (!(Get-Module -Name BcContainerHelper -ListAvailable)) {
        Write-Host "Installing BcContainerHelper module..." -ForegroundColor Yellow
        Install-Module -Name BcContainerHelper -Scope CurrentUser -Force -AllowClobber
    }

    Import-Module -Name BcContainerHelper -DisableNameChecking -Force -ErrorAction Stop

    # Configure BcContainerHelper
    $bcContainerHelperConfig.MicrosoftTelemetryConnectionString = ""

    Write-Host "✓ BcContainerHelper loaded successfully" -ForegroundColor Green
    $useBcContainerHelper = $true

}
catch {
    Write-Warning "BcContainerHelper failed to load: $($_.Exception.Message)"
    Write-Host "Error Details:" -ForegroundColor Red
    Write-Host "  Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Gray
    Write-Host "  Stack Trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    if ($_.Exception.InnerException) {
        Write-Host "  Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Gray
    }
    Write-Host "Falling back to direct Docker commands..." -ForegroundColor Yellow
    $useBcContainerHelper = $false
}

# Check if Docker is available
try {
    $dockerVersion = & docker --version
    Write-Host "Docker detected: $dockerVersion" -ForegroundColor Green
}
catch {
    Write-Warning "Docker not available. Container creation will be skipped."
    Write-Host "For Linux development without containers, run with -skipContainer" -ForegroundColor Yellow
    return
}

if ($useBcContainerHelper) {
    # Use BcContainerHelper standard approach
    Write-Host "Using BcContainerHelper for container management..." -ForegroundColor Green

    try {
        # Remove existing container if it exists
        $existingContainers = Get-BcContainers | Where-Object { $_.Name -eq $containerName }
        if ($existingContainers) {
            Write-Host "Removing existing container '$containerName'..." -ForegroundColor Yellow
            Remove-BcContainer -containerName $containerName -Force
        }

        # Get the latest BC artifacts for the specified version
        Write-Host "Getting Business Central artifacts for version $bcVersion..." -ForegroundColor Yellow
        $artifactUrl = Get-BcArtifactUrl -version $bcVersion -country "us" -select "Latest"
        Write-Host "Using artifact URL: $artifactUrl" -ForegroundColor Cyan

        # Container parameters
        $containerParameters = @{
            "containerName"       = $containerName
            "accept_eula"         = $true
            "Isolation"           = "process"
            "memoryLimit"         = $memoryLimit
            "auth"                = "UserPassword"
            "Credential"          = (New-Object System.Management.Automation.PSCredential("admin", (ConvertTo-SecureString "P@ssword1" -AsPlainText -Force)))
            "updateHosts"         = $true
            "usessl"              = $false
            "enableTaskScheduler" = $false
            "artifactUrl"         = $artifactUrl
        }

        # Add license file if provided
        if ($licenseFile -and (Test-Path $licenseFile)) {
            $containerParameters["licenseFile"] = $licenseFile
            Write-Host "Using license file: $licenseFile" -ForegroundColor Green
        }
        else {
            Write-Host "Using developer license (container will expire after 90 days)" -ForegroundColor Yellow
        }

        # Create the container using BcContainerHelper
        Write-Host "Creating Business Central container '$containerName'..." -ForegroundColor Yellow
        New-BcContainer @containerParameters

        # Wait for container to be ready
        Write-Host "Waiting for container to be fully ready..." -ForegroundColor Yellow
        Wait-BcContainerReady -containerName $containerName -timeout 600

        # Get container information using BcContainerHelper
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

    }
    catch {
        Write-Warning "BcContainerHelper container creation failed: $($_.Exception.Message)"
        Write-Host "Detailed Error Information:" -ForegroundColor Red
        Write-Host "  Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Gray
        Write-Host "  Error Category: $($_.CategoryInfo.Category)" -ForegroundColor Gray
        Write-Host "  Error ID: $($_.FullyQualifiedErrorId)" -ForegroundColor Gray
        Write-Host "  Stack Trace:" -ForegroundColor Gray
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
        if ($_.Exception.InnerException) {
            Write-Host "  Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Gray
            Write-Host "  Inner Exception Type: $($_.Exception.InnerException.GetType().FullName)" -ForegroundColor Gray
        }
        Write-Host "  Error Record:" -ForegroundColor Gray
        Write-Host ($_ | Format-List * | Out-String) -ForegroundColor Gray
        Write-Host "Falling back to direct Docker approach..." -ForegroundColor Yellow
        $useBcContainerHelper = $false
    }
}

if (-not $useBcContainerHelper) {
    # Fallback to direct Docker commands
    Write-Host "Using direct Docker commands..." -ForegroundColor Yellow

    # Stop and remove existing container if it exists
    try {
        $existingContainer = & docker ps -a --filter "name=$containerName" --format "{{.Names}}" 2>$null
        if ($existingContainer -eq $containerName) {
            Write-Host "Removing existing container '$containerName'..." -ForegroundColor Yellow
            & docker stop $containerName 2>$null | Out-Null
            & docker rm $containerName 2>$null | Out-Null
        }
    }
    catch {
        # Container doesn't exist or docker command failed, continue
    }

    # Business Central container image mapping (fallback when artifacts fail)
    $bcImageMap = @{
        "27" = "mcr.microsoft.com/businesscentral:10.0.22631.4317-ltsc2022"
        "26" = "mcr.microsoft.com/businesscentral:10.0.22000.2777-ltsc2022"
        "25" = "mcr.microsoft.com/businesscentral:10.0.20348.2762-ltsc2022"
        "24" = "mcr.microsoft.com/businesscentral:10.0.20348.2402-ltsc2022"
    }

    $bcImage = $bcImageMap[$bcVersion]
    if (-not $bcImage) {
        $bcImage = "mcr.microsoft.com/businesscentral:latest"
        Write-Warning "Unknown BC version '$bcVersion', using latest image: $bcImage"
    }
    else {
        Write-Host "Using BC image: $bcImage" -ForegroundColor Cyan
    }

    # Create the container using Docker directly
    Write-Host "Creating Business Central container '$containerName'..." -ForegroundColor Yellow

    $dockerArgs = @(
        "run", "-d"
        "--name", $containerName
        "--memory", $memoryLimit.ToLower()
        "-p", "80:80"
        "-p", "443:443"
        "-p", "7046:7046"
        "-p", "7047:7047"
        "-p", "7048:7048"
        "-p", "7049:7049"
        "-p", "8080:8080"
        "-e", "accept_eula=y"
        "-e", "username=admin"
        "-e", "password=P@ssword1"
        "-e", "auth=UserPassword"
        "-e", "updateHosts=y"
        "-e", "usessl=n"
    )

    # Add license file if provided
    if ($licenseFile -and (Test-Path $licenseFile)) {
        $dockerArgs += @("-v", "${licenseFile}:/run/my/license.flf")
        $dockerArgs += @("-e", "licenseFile=/run/my/license.flf")
        Write-Host "Using license file: $licenseFile" -ForegroundColor Green
    }
    else {
        Write-Host "Using developer license (container will expire after 90 days)" -ForegroundColor Yellow
    }

    $dockerArgs += $bcImage

    try {
        Write-Host "Running: docker $($dockerArgs -join ' ')" -ForegroundColor Gray
        $containerId = & docker @dockerArgs

        if ($LASTEXITCODE -ne 0) {
            throw "Docker run command failed with exit code $LASTEXITCODE"
        }

        Write-Host "Container created with ID: $($containerId.Substring(0,12))" -ForegroundColor Green

        # Wait for container to be ready
        Write-Host "Waiting for container to be ready..." -ForegroundColor Yellow
        $maxRetries = 60
        $retries = 0
        $containerReady = $false

        while ($retries -lt $maxRetries -and -not $containerReady) {
            Start-Sleep -Seconds 10
            $retries++

            try {
                $containerStatus = & docker inspect --format='{{.State.Status}}' $containerName 2>$null
                if ($containerStatus -eq "running") {
                    # Check if web client is responding
                    $webclientUrl = "http://localhost:80/BC"
                    try {
                        Invoke-WebRequest -Uri $webclientUrl -TimeoutSec 5 -UseBasicParsing 2>$null | Out-Null
                        $containerReady = $true
                        Write-Host "Container is ready! Web client responding at: $webclientUrl" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Attempt $retries/$maxRetries - Container running but web client not ready yet..." -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Host "Attempt $retries/$maxRetries - Container status: $containerStatus" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "Attempt $retries/$maxRetries - Checking container status..." -ForegroundColor Yellow
            }
        }

        if (-not $containerReady) {
            Write-Warning "Container may not be fully ready. Check logs with: docker logs $containerName"
        }

        # Get container information
        $containerInfo = & docker inspect --format='{{.Config.Image}} {{.State.Status}}' $containerName
        $webclientUrl = "http://localhost:80/BC"

        Write-Host ""
        Write-Host "✅ Business Central container setup completed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Container Information:" -ForegroundColor White
        Write-Host "  Name: $containerName" -ForegroundColor Cyan
        Write-Host "  Image: $bcImage" -ForegroundColor Cyan
        Write-Host "  Status: $($containerInfo.Split(' ')[1])" -ForegroundColor Cyan
        Write-Host "  Web Client: $webclientUrl" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Credentials:" -ForegroundColor White
        Write-Host "  Username: admin" -ForegroundColor Cyan
        Write-Host "  Password: P@ssword1" -ForegroundColor Cyan

    }
    catch {
        Write-Error "Failed to create container with Docker: $($_.Exception.Message)"

        # Clean up on failure
        try {
            & docker stop $containerName 2>$null | Out-Null
            & docker rm $containerName 2>$null | Out-Null
            Write-Host "Cleaned up failed container" -ForegroundColor Yellow
        }
        catch {
            # Ignore cleanup errors
        }

        throw
    }
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. Compile apps using the compilation scripts in .github/.tmp/" -ForegroundColor Yellow
Write-Host "  2. Use BcContainerHelper cmdlets for app management (if available)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Useful Commands:" -ForegroundColor White
if ($useBcContainerHelper) {
    Write-Host "  Stop container:   Stop-BcContainer -containerName '$containerName'" -ForegroundColor Cyan
    Write-Host "  Remove container: Remove-BcContainer -containerName '$containerName'" -ForegroundColor Cyan
    Write-Host "  Container shell:  Enter-BcContainer -containerName '$containerName'" -ForegroundColor Cyan
    Write-Host "  Publish app:      Publish-BcContainerApp -containerName '$containerName' -appFile 'path/to/app.app'" -ForegroundColor Cyan
}
else {
    Write-Host "  View logs:        docker logs $containerName" -ForegroundColor Cyan
    Write-Host "  Stop container:   docker stop $containerName" -ForegroundColor Cyan
    Write-Host "  Remove container: docker rm $containerName" -ForegroundColor Cyan
    Write-Host "  Container shell:  docker exec -it $containerName powershell" -ForegroundColor Cyan
}
