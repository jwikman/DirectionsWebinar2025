#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run all AL test codeunits using the test runner

.DESCRIPTION
    This script runs all test codeunits in the Library Test App sequentially
    and reports the results. This demonstrates the functionality that would
    be provided by the al-test-runner MCP server.

.PARAMETER BaseUrl
    The base URL of the Business Central instance

.PARAMETER Tenant
    The tenant name (default: "default")

.PARAMETER Username
    Username for authentication

.PARAMETER Password
    Password for authentication as SecureString

.PARAMETER MaxWaitSeconds
    Maximum time to wait for each test execution

.EXAMPLE
    ./run-all-tests.ps1 -BaseUrl "http://localhost:7048/BC" -Username "admin"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = "http://localhost:7048/BC",

    [Parameter(Mandatory = $false)]
    [string]$Tenant = "default",

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [SecureString]$Password,

    [Parameter(Mandatory = $false)]
    [int]$MaxWaitSeconds = 300
)

#Requires -Version 7.0

$ErrorActionPreference = "Stop"

# Get credentials from environment variables if not provided
if (-not $Username -and $env:BC_USERNAME) {
    $Username = $env:BC_USERNAME
}
if (-not $Password -and $env:BC_PASSWORD) {
    $Password = ConvertTo-SecureString $env:BC_PASSWORD -AsPlainText -Force
}

# Validate required credentials
if (-not $Username -or -not $Password) {
    Write-Host "Error: Username and Password are required" -ForegroundColor Red
    exit 1
}

# Define all test codeunits
$TestCodeunits = @(
    @{ Id = 70450; Name = "LIB Library Member Tests"; TestCount = 4 }
    @{ Id = 70451; Name = "LIB Library Author Tests"; TestCount = 5 }
    @{ Id = 70452; Name = "LIB Library Book Tests"; TestCount = 7 }
    @{ Id = 70453; Name = "LIB Library Book Loan Tests"; TestCount = 6 }
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AL Test Runner - All Tests Execution" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host "  Tenant: $Tenant" -ForegroundColor Gray
Write-Host "  Username: $Username" -ForegroundColor Gray
Write-Host "  Test Codeunits: $($TestCodeunits.Count)" -ForegroundColor Gray
Write-Host "  Total Tests: $($TestCodeunits | Measure-Object -Property TestCount -Sum | Select-Object -ExpandProperty Sum)" -ForegroundColor Gray
Write-Host ""

$TotalPassed = 0
$TotalFailed = 0
$TotalSkipped = 0
$Results = @()

foreach ($codeunit in $TestCodeunits) {
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "Running: $($codeunit.Name) (ID: $($codeunit.Id))" -ForegroundColor Yellow
    Write-Host "Expected Tests: $($codeunit.TestCount)" -ForegroundColor Gray
    Write-Host ""

    try {
        # Run the test codeunit using the existing script
        $scriptPath = Join-Path $PSScriptRoot "run-tests-odata.ps1"
        
        $output = & $scriptPath `
            -BaseUrl $BaseUrl `
            -Tenant $Tenant `
            -Username $Username `
            -Password $Password `
            -CodeunitId $codeunit.Id `
            -MaxWaitSeconds $MaxWaitSeconds 2>&1

        $exitCode = $LASTEXITCODE
        
        # Output the test results
        Write-Host ($output | Out-String) -ForegroundColor Gray

        if ($exitCode -eq 0) {
            Write-Host "✓ PASSED: $($codeunit.Name)" -ForegroundColor Green
            $TotalPassed += $codeunit.TestCount
            $Results += @{
                Codeunit = $codeunit.Name
                Status = "PASSED"
                TestCount = $codeunit.TestCount
            }
        }
        else {
            Write-Host "✗ FAILED: $($codeunit.Name)" -ForegroundColor Red
            $TotalFailed += $codeunit.TestCount
            $Results += @{
                Codeunit = $codeunit.Name
                Status = "FAILED"
                TestCount = $codeunit.TestCount
            }
        }
    }
    catch {
        Write-Host "✗ ERROR: $($codeunit.Name)" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        $TotalFailed += $codeunit.TestCount
        $Results += @{
            Codeunit = $codeunit.Name
            Status = "ERROR"
            TestCount = $codeunit.TestCount
            Error = $_.Exception.Message
        }
    }

    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Execution Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($result in $Results) {
    $statusColor = if ($result.Status -eq "PASSED") { "Green" } else { "Red" }
    $statusIcon = if ($result.Status -eq "PASSED") { "✓" } else { "✗" }
    Write-Host "  $statusIcon $($result.Codeunit): $($result.Status) ($($result.TestCount) tests)" -ForegroundColor $statusColor
    if ($result.Error) {
        Write-Host "    Error: $($result.Error)" -ForegroundColor DarkRed
    }
}

Write-Host ""
Write-Host "Results:" -ForegroundColor Yellow
Write-Host "  Total Test Methods: $($TotalPassed + $TotalFailed)" -ForegroundColor Gray
Write-Host "  Passed: $TotalPassed" -ForegroundColor Green
Write-Host "  Failed: $TotalFailed" -ForegroundColor $(if ($TotalFailed -eq 0) { "Gray" } else { "Red" })
Write-Host ""

if ($TotalFailed -eq 0) {
    Write-Host "=== ALL TESTS PASSED ===" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "=== SOME TESTS FAILED ===" -ForegroundColor Red
    exit 1
}
