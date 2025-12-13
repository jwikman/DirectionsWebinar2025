#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for running AL tests in GitHub Actions

.DESCRIPTION
    Tests the Run-ALTests.ps1 script against a BC container running on localhost
    Designed for Linux/GitHub Actions environments
#>

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Testing AL Test Runner - GitHub Actions" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Configuration for GitHub Actions
# IMPORTANT: Include tenant in the URL for multi-tenant environments
$serviceUrl = "http://localhost/BC/WebClient?tenant=default"
$username = "admin"
$password = ConvertTo-SecureString "admin123!" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)

Write-Host "Configuration:"
Write-Host "  Service URL: $serviceUrl"
Write-Host "  Username: $username"
Write-Host "  Auth Type: UserPassword"
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
