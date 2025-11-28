<#
.SYNOPSIS
    Test script for Linux compatibility of BC development setup
.DESCRIPTION
    This script tests the Linux-compatible setup and identifies any remaining
    Windows-specific dependencies or issues.
.PARAMETER testCompilation
    Test AL compilation functionality
.PARAMETER testContainerSetup
    Test container setup functionality (requires Docker)
.EXAMPLE
    .\test-linux-compatibility.ps1 -testCompilation
    .\test-linux-compatibility.ps1 -testCompilation -testContainerSetup
#>

[CmdletBinding()]
param(
    [switch]$testCompilation = $true,
    [switch]$testContainerSetup = $false
)

$ErrorActionPreference = "Stop"

Write-Host "Testing Linux compatibility for BC development environment..." -ForegroundColor Green
Write-Host ""

# Test environment detection
Write-Host "Environment Detection:" -ForegroundColor White
Write-Host "  Platform: $($IsLinux ? 'Linux' : 'Windows')" -ForegroundColor Cyan
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host "  OS: $($PSVersionTable.OS)" -ForegroundColor Cyan

# Test paths
$projectRoot = $PWD.Path
$appFolder = Join-Path $projectRoot "App"
$testAppFolder = Join-Path $projectRoot "TestApp"
$githubFolder = Join-Path $projectRoot ".github"
$tempFolder = Join-Path $githubFolder ".tmp"

Write-Host ""
Write-Host "Path Validation:" -ForegroundColor White
Write-Host "  Project Root: $(Test-Path $projectRoot ? '✓' : '✗') $projectRoot" -ForegroundColor $(Test-Path $projectRoot ? 'Green' : 'Red')
Write-Host "  App Folder: $(Test-Path $appFolder ? '✓' : '✗') $appFolder" -ForegroundColor $(Test-Path $appFolder ? 'Green' : 'Red')
Write-Host "  TestApp Folder: $(Test-Path $testAppFolder ? '✓' : '✗') $testAppFolder" -ForegroundColor $(Test-Path $testAppFolder ? 'Green' : 'Red')
Write-Host "  .github Folder: $(Test-Path $githubFolder ? '✓' : '✗') $githubFolder" -ForegroundColor $(Test-Path $githubFolder ? 'Green' : 'Red')

# Test required scripts
$initScript = Join-Path $githubFolder "initialize-coding-agent.ps1"
$linuxSetupScript = Join-Path $githubFolder "setup-bc-container-linux.ps1"
$symbolDownloadScript = Join-Path $githubFolder "download-al-symbols-linux.ps1"

Write-Host ""
Write-Host "Script Availability:" -ForegroundColor White
Write-Host "  Initialize Script: $(Test-Path $initScript ? '✓' : '✗') $initScript" -ForegroundColor $(Test-Path $initScript ? 'Green' : 'Red')
Write-Host "  Linux Setup Script: $(Test-Path $linuxSetupScript ? '✓' : '✗') $linuxSetupScript" -ForegroundColor $(Test-Path $linuxSetupScript ? 'Green' : 'Red')
Write-Host "  Symbol Downloader: $(Test-Path $symbolDownloadScript ? '✓' : '✗') $symbolDownloadScript" -ForegroundColor $(Test-Path $symbolDownloadScript ? 'Green' : 'Red')

# Test .NET tools availability
Write-Host ""
Write-Host "Development Tools:" -ForegroundColor White
try {
    $dotnetVersion = & dotnet --version 2>$null
    Write-Host "  .NET SDK: ✓ $dotnetVersion" -ForegroundColor Green
} catch {
    Write-Host "  .NET SDK: ✗ Not found" -ForegroundColor Red
}

try {
    $alTools = & dotnet tool list --global | Select-String "BusinessCentral.Development.Tools"
    if ($alTools) {
        Write-Host "  AL Tools: ✓ $($alTools.ToString().Trim())" -ForegroundColor Green
    } else {
        Write-Host "  AL Tools: ✗ Not installed" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  AL Tools: ✗ Error checking installation" -ForegroundColor Red
}

# Test PowerShell modules
Write-Host ""
Write-Host "PowerShell Modules:" -ForegroundColor White
try {
    $bcModule = Get-Module -Name BcContainerHelper -ListAvailable -ErrorAction SilentlyContinue
    if ($bcModule) {
        Write-Host "  BcContainerHelper: ✓ Available (v$($bcModule.Version))" -ForegroundColor Green

        # Test import
        try {
            Import-Module -Name BcContainerHelper -DisableNameChecking -ErrorAction Stop
            Write-Host "  BcContainerHelper Import: ✓ Success" -ForegroundColor Green
        } catch {
            Write-Host "  BcContainerHelper Import: ✗ Failed - $($_.Exception.Message)" -ForegroundColor $(($IsLinux) ? 'Yellow' : 'Red')
            if ($IsLinux) {
                Write-Host "    This is expected on Linux due to Windows dependencies" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  BcContainerHelper: ✗ Not available" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  BcContainerHelper: ✗ Error checking module" -ForegroundColor Red
}

# Test Docker availability (if requested)
if ($testContainerSetup) {
    Write-Host ""
    Write-Host "Container Support:" -ForegroundColor White
    try {
        $dockerVersion = & docker --version 2>$null
        Write-Host "  Docker: ✓ $dockerVersion" -ForegroundColor Green

        # Test Docker daemon
        try {
            $dockerInfo = & docker info 2>$null
            Write-Host "  Docker Daemon: ✓ Running" -ForegroundColor Green
        } catch {
            Write-Host "  Docker Daemon: ✗ Not running or accessible" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Docker: ✗ Not found" -ForegroundColor Red
    }
}

# Test compilation setup (if requested)
if ($testCompilation) {
    Write-Host ""
    Write-Host "Compilation Test:" -ForegroundColor White

    try {
        # Run initialization script
        Write-Host "  Running initialization script..." -ForegroundColor Yellow
        & $initScript -ErrorAction Stop

        # Check if compilation scripts were created
        $compileAppScript = Join-Path $tempFolder "compile-app.ps1"
        $compileTestAppScript = Join-Path $tempFolder "compile-testapp.ps1"

        Write-Host "  App Compile Script: $(Test-Path $compileAppScript ? '✓' : '✗') Created" -ForegroundColor $(Test-Path $compileAppScript ? 'Green' : 'Red')
        Write-Host "  TestApp Compile Script: $(Test-Path $compileTestAppScript ? '✓' : '✗') Created" -ForegroundColor $(Test-Path $compileTestAppScript ? 'Green' : 'Red')

        if (Test-Path $compileAppScript) {
            Write-Host "  Testing app compilation..." -ForegroundColor Yellow
            try {
                & $compileAppScript
                Write-Host "  App Compilation: ✓ Success" -ForegroundColor Green
            } catch {
                Write-Host "  App Compilation: ✗ Failed - $($_.Exception.Message)" -ForegroundColor Red
            }
        }

    } catch {
        Write-Host "  Initialization: ✗ Failed - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test container setup (if requested)
if ($testContainerSetup) {
    Write-Host ""
    Write-Host "Container Setup Test:" -ForegroundColor White

    try {
        Write-Host "  Testing Linux container setup..." -ForegroundColor Yellow
        & $linuxSetupScript -skipContainer -ErrorAction Stop
        Write-Host "  Container Setup (skip): ✓ Success" -ForegroundColor Green
    } catch {
        Write-Host "  Container Setup: ✗ Failed - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "✅ Linux compatibility test completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor White
if ($IsLinux) {
    Write-Host "  • Running on Linux - using Linux-compatible setup" -ForegroundColor Green
    Write-Host "  • BcContainerHelper may not import (expected)" -ForegroundColor Yellow
    Write-Host "  • AL compilation should work with symbol downloader" -ForegroundColor Green
    Write-Host "  • Container functionality limited to Docker commands" -ForegroundColor Yellow
} else {
    Write-Host "  • Running on Windows - full BcContainerHelper available" -ForegroundColor Green
    Write-Host "  • All functionality should work normally" -ForegroundColor Green
}