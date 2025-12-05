#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Publish AL apps to BC container via API

.DESCRIPTION
    Publishes the main app and test app to a Business Central container using the Development API

.PARAMETER BaseUrl
    Base URL of the BC container (default: http://localhost:7049/BC)

.PARAMETER Username
    Username for authentication (required)

.EXAMPLE
    $env:BC_PASSWORD = "Admin123!"
    ./publish-apps-to-container.ps1 -Username "admin"

.EXAMPLE
    $env:BC_PASSWORD = "Admin123!"
    ./publish-apps-to-container.ps1 -BaseUrl "http://localhost:7049/BC" -Username "admin"

.NOTES
    Requires environment variable:
    - BC_PASSWORD: Business Central admin user password
#>

param(
    [string]$BaseUrl = "http://localhost:7049/BC",

    [Parameter(Mandatory = $true)]
    [string]$Username
)

$ErrorActionPreference = "Stop"

# Get password from environment variable
if (-not $env:BC_PASSWORD) {
    Write-Host "ERROR: BC_PASSWORD environment variable not set" -ForegroundColor Red
    Write-Host "Set it with: `$env:BC_PASSWORD = 'YourPassword'" -ForegroundColor Yellow
    exit 1
}
$Password = $env:BC_PASSWORD

Write-Host "=== Publishing Apps to BC Container ===" -ForegroundColor Cyan

# Create Basic auth header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
$Headers = @{
    "Authorization" = "Basic $base64AuthInfo"
}

# Publish Main App
Write-Host "Publishing The Library (main app) to BC container..." -ForegroundColor Yellow

# Find the main app file
$appFile = Get-ChildItem -Path "./App" -Filter "*.app" -File -Depth 0 | Select-Object -First 1
if (-not $appFile) {
    Write-Host "ERROR: No main app file found for publishing" -ForegroundColor Red
    exit 1
}

Write-Host "Publishing app file: $($appFile.Name)" -ForegroundColor Gray
Write-Host "  File path: $($appFile.FullName)" -ForegroundColor DarkGray
Write-Host "  File size: $([math]::Round($appFile.Length / 1KB, 2)) KB" -ForegroundColor DarkGray

# Publish extension to BC container using API
# Format matches VSCode publish request - field name should be the actual filename
$uri = "$BaseUrl/dev/apps?tenant=default&SchemaUpdateMode=synchronize&DependencyPublishingOption=default"
Write-Host "  URI: $uri" -ForegroundColor DarkGray
$fileName = $appFile.Name
Write-Host "  Form field name: $fileName" -ForegroundColor DarkGray
$form = @{
    $fileName = $appFile
}

Write-Host "  Sending request..." -ForegroundColor DarkGray
$maxRetries = 3
$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    try {
        if ($retryCount -gt 0) {
            Write-Host "  Retry attempt $retryCount of $maxRetries..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }

        $response = Invoke-WebRequest -Uri $uri -Method Post -Headers $Headers `
            -Form $form `
            -UseBasicParsing -AllowUnencryptedAuthentication `
            -TimeoutSec 300 -Verbose
        Write-Host "  Response status: $($response.StatusCode)" -ForegroundColor DarkGray

        if ($response.StatusCode -ne 200 -and $response.StatusCode -ne 204) {
            Write-Host "ERROR: Failed to publish main app. Status: $($response.StatusCode)" -ForegroundColor Red
            Write-Host "Response: $($response.Content)" -ForegroundColor Yellow
            exit 1
        }

        $success = $true
    }
    catch {
        $retryCount++
        Write-Host "  ERROR during request (attempt $retryCount): $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Exception type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkGray

        if ($_.Exception.InnerException) {
            Write-Host "  Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor DarkGray
        }

        if ($_.Exception.Response) {
            Write-Host "  Response status: $($_.Exception.Response.StatusCode)" -ForegroundColor DarkGray
        }

        if ($retryCount -ge $maxRetries) {
            Write-Host "  All retry attempts failed" -ForegroundColor Red
            throw
        }
    }
}

Write-Host "✓ Main app published successfully" -ForegroundColor Green

# Publish Test App (with dependencies)
Write-Host "Publishing The Library Tester (test app) to BC container..." -ForegroundColor Yellow

# Find the test app .app file (not .dep.app)
$testAppFile = Get-ChildItem -Path "./TestApp" -Filter "*.app" -File -Depth 0 |
    Where-Object { $_.Name -notlike "*.dep.app" } |
    Select-Object -First 1

if (-not $testAppFile) {
    Write-Host "ERROR: No test app file found" -ForegroundColor Red
    exit 1
}

# Create .dep.app file with dependencies
# Note: We publish a .dep.app instead of the .app file because the .dep.app format automatically
# installs any dependencies that are already published but not yet installed in the environment.
# This ensures all required apps are installed in the correct order.
Write-Host "Creating .dep.app package with dependencies..." -ForegroundColor Gray

# Find the Create-DepApp.ps1 script
$createDepAppScript = Join-Path $PSScriptRoot "./create-dep-app.ps1" -Resolve

# Create .dep.app with main app as dependency
$depAppPath = & $createDepAppScript -AppPath $testAppFile.FullName -DependencyPaths @($appFile.FullName)

if (-not $depAppPath -or -not (Test-Path $depAppPath)) {
    Write-Host "ERROR: Failed to create .dep.app file" -ForegroundColor Red
    exit 1
}

Write-Host "Created .dep.app: $depAppPath" -ForegroundColor Gray

# Publish the .dep.app file
$depAppFile = Get-Item $depAppPath
Write-Host "Publishing test app file: $($depAppFile.Name)" -ForegroundColor Gray
Write-Host "  File path: $($depAppFile.FullName)" -ForegroundColor DarkGray
Write-Host "  File size: $([math]::Round($depAppFile.Length / 1KB, 2)) KB" -ForegroundColor DarkGray

$fileName = $depAppFile.Name
Write-Host "  Form field name: $fileName" -ForegroundColor DarkGray
$form = @{
    $fileName = $depAppFile
}

Write-Host "  Sending request..." -ForegroundColor DarkGray
$maxRetries = 3
$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    try {
        if ($retryCount -gt 0) {
            Write-Host "  Retry attempt $retryCount of $maxRetries..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }

        $response = Invoke-WebRequest -Uri $uri -Method Post -Headers $Headers `
            -Form $form `
            -UseBasicParsing -AllowUnencryptedAuthentication `
            -TimeoutSec 300 -Verbose
        Write-Host "  Response status: $($response.StatusCode)" -ForegroundColor DarkGray

        if ($response.StatusCode -ne 200 -and $response.StatusCode -ne 204) {
            Write-Host "ERROR: Failed to publish test app. Status: $($response.StatusCode)" -ForegroundColor Red
            Write-Host "Response: $($response.Content)" -ForegroundColor Yellow
            exit 1
        }

        $success = $true
    }
    catch {
        $retryCount++
        Write-Host "  ERROR during request (attempt $retryCount): $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Exception type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkGray

        if ($_.Exception.InnerException) {
            Write-Host "  Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor DarkGray
        }

        if ($_.Exception.Response) {
            Write-Host "  Response status: $($_.Exception.Response.StatusCode)" -ForegroundColor DarkGray
        }

        if ($retryCount -ge $maxRetries) {
            Write-Host "  All retry attempts failed" -ForegroundColor Red
            throw
        }
    }
}

Write-Host "✓ All apps published successfully" -ForegroundColor Green
