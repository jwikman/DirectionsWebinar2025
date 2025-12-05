#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup .NET 8.0 and AL Language development tools

.DESCRIPTION
    Verifies .NET SDK installation and installs BC Development Tools for Linux

.PARAMETER ALVersion
    AL Language version to install (default: 17.0.28.6483-beta)

.EXAMPLE
    ./setup-dotnet-and-al.ps1
    ./setup-dotnet-and-al.ps1 -ALVersion "17.0.28.6483-beta"
#>

param(
    [string]$ALVersion = "17.0.28.6483-beta"
)

$ErrorActionPreference = "Stop"

Write-Host "Installing .NET 8.0 SDK..." -ForegroundColor Cyan

# .NET SDK is pre-installed on ubuntu-latest runners
# Just verify it's available
dotnet --version

# Install AL Language development tools
Write-Host "Installing BC Development Tools (version $ALVersion)..." -ForegroundColor Yellow
dotnet tool install -g Microsoft.Dynamics.BusinessCentral.Development.Tools.Linux --version $ALVersion

# Ensure dotnet tools are in PATH
$dotnetToolsPath = Join-Path $HOME ".dotnet/tools"
$env:PATH = "$env:PATH$([System.IO.Path]::PathSeparator)$dotnetToolsPath"

# On GitHub Actions, add to GITHUB_PATH
if ($env:GITHUB_PATH) {
    Add-Content -Path $env:GITHUB_PATH -Value $dotnetToolsPath
}

# Verify BC Development Tools installation
Write-Host "Verifying BC Development Tools installation..." -ForegroundColor Yellow
# Test AL command directly (ignore exit code since al --version returns 1)
try {
    al --version
}
catch {
    # Expected - al --version returns exit code 1 even on success
    Write-Host "AL tools installed (version check returned expected non-zero exit code)" -ForegroundColor Gray
}

Write-Host ".NET and AL tools setup completed successfully" -ForegroundColor Green
