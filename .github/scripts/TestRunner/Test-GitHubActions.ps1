#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for running AL tests in GitHub Actions

.DESCRIPTION
    Tests the Run-ALTests.ps1 script against a BC container running on localhost
    Designed for Linux/GitHub Actions environments
    
    NOTE: This script requires the Business Central WebClient to be accessible.
    For Docker/Wine-based BC environments without WebClient, use run-tests-odata.ps1 instead.
#>

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Testing AL Test Runner - GitHub Actions" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Configuration for GitHub Actions
# IMPORTANT: Include tenant in the URL for multi-tenant environments
$serviceUrl = "http://localhost/BC"
$username = "admin"
$password = ConvertTo-SecureString "Admin123!" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)

Write-Host "Configuration:"
Write-Host "  Service URL: $serviceUrl"
Write-Host "  Username: $username"
Write-Host "  Auth Type: UserPassword"
Write-Host ""

# Check if WebClient endpoint is accessible
Write-Host "Checking WebClient availability..." -ForegroundColor Yellow
$webClientUrl = "$serviceUrl/WebClient"
try {
    $response = Invoke-WebRequest -Uri $webClientUrl -Method Head -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✓ WebClient is accessible" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ WebClient is NOT accessible" -ForegroundColor Red
    Write-Host ""
    Write-Host "ERROR: The WebClient endpoint is required but not available." -ForegroundColor Red
    Write-Host ""
    Write-Host "This typically occurs in Docker/Wine-based BC environments where" -ForegroundColor Yellow
    Write-Host "the WebClient component is not configured with a web server (nginx/IIS)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Solutions:" -ForegroundColor Cyan
    Write-Host "  1. Use the OData-based test runner instead:" -ForegroundColor White
    Write-Host "     pwsh .github/scripts/run-tests-odata.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Configure a web server (nginx) to serve the WebClient files" -ForegroundColor White
    Write-Host "     from: /home/bcartifacts/WebClient/PFiles/Microsoft Dynamics NAV/*/Web Client/WebPublish" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Use a Windows-based BC environment with IIS configured" -ForegroundColor White
    Write-Host ""
    exit 1
}
Write-Host ""

# Test parameters
$testParams = @{
    ServiceUrl = $serviceUrl
    Credential = $credential
    Tenant = "default"
    TestSuite = "DEFAULT"
    TestCodeunit = "*"
    TestPage = 130455
    Detailed = $true
    Culture = "en-US"
}

# Get script path
$scriptPath = Join-Path $PSScriptRoot "Run-ALTests.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Run-ALTests.ps1 not found at: $scriptPath"
    exit 1
}

Write-Host "Starting test execution..." -ForegroundColor Green
Write-Host ""

try {
    & $scriptPath @testParams
    Write-Host ""
    Write-Host "Test execution completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Error "Test execution failed: $_"
    exit 1
}
