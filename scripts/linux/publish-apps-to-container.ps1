#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Publish AL apps to BC container via API

.DESCRIPTION
    Publishes the main app and test app to a Business Central container using the Development API

.PARAMETER BaseUrl
    Base URL of the BC container (default: http://localhost:7049)

.PARAMETER Username
    Username for authentication (required)

.PARAMETER Password
    Password for authentication (required)

.EXAMPLE
    ./publish-apps-to-container.ps1 -Username "admin" -Password "Admin123!"
    ./publish-apps-to-container.ps1 -BaseUrl "http://localhost:7049" -Username "admin" -Password "Admin123!"
#>

param(
    [string]$BaseUrl = "http://localhost:7049",

    [Parameter(Mandatory = $true)]
    [string]$Username,

    [Parameter(Mandatory = $true)]
    [string]$Password
)

$ErrorActionPreference = "Stop"

Write-Host "=== Publishing Apps to BC Container ===" -ForegroundColor Cyan

# Create credentials for authentication
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)

# Publish Main App
Write-Host "Publishing The Library (main app) to BC container..." -ForegroundColor Yellow

# Find the main app file
$appFile = Get-ChildItem -Path "./App" -Filter "*.app" -File -Depth 0 | Select-Object -First 1
if (-not $appFile) {
    Write-Host "ERROR: No main app file found for publishing" -ForegroundColor Red
    exit 1
}

Write-Host "Publishing app file: $($appFile.FullName)" -ForegroundColor Gray

# Publish extension to BC container using API
$uri = "$BaseUrl/BC/dev/apps?tenant=default&SchemaUpdateMode=synchronize&DependencyPublishingOption=default"
$response = Invoke-WebRequest -Uri $uri -Method Post -Credential $credential `
    -InFile $appFile.FullName -ContentType "application/octet-stream" `
    -UseBasicParsing -AllowUnencryptedAuthentication

if ($response.StatusCode -ne 200 -and $response.StatusCode -ne 204) {
    Write-Host "ERROR: Failed to publish main app. Status: $($response.StatusCode)" -ForegroundColor Red
    exit 1
}

# Publish Test App
Write-Host "Publishing The Library Tester (test app) to BC container..." -ForegroundColor Yellow

# Find the test app file (excluding .dep.app files)
$testAppFile = Get-ChildItem -Path "./TestApp" -Filter "*.app" -File -Depth 0 |
    Where-Object { $_.Name -notlike "*.dep.app" } |
    Select-Object -First 1

if (-not $testAppFile) {
    Write-Host "ERROR: No test app file found for publishing" -ForegroundColor Red
    exit 1
}

Write-Host "Publishing test app file: $($testAppFile.FullName)" -ForegroundColor Gray

# Publish extension to BC container using API
$response = Invoke-WebRequest -Uri $uri -Method Post -Credential $credential `
    -InFile $testAppFile.FullName -ContentType "application/octet-stream" `
    -UseBasicParsing

if ($response.StatusCode -ne 200 -and $response.StatusCode -ne 204) {
    Write-Host "ERROR: Failed to publish test app. Status: $($response.StatusCode)" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All apps published successfully" -ForegroundColor Green
