#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Compile AL application (App or TestApp)

.DESCRIPTION
    Compiles one or all AL applications in the workspace. If no project path is provided,
    compiles both App and TestApp in order, copying the main app to .alpackages so TestApp can reference it.

.PARAMETER ProjectPath
    Path to the specific project to compile (e.g., "./App" or "./TestApp").
    If not provided, compiles both App and TestApp in order.

.EXAMPLE
    ./compile-al-apps.ps1
    Compiles both App and TestApp in order

.EXAMPLE
    ./compile-al-apps.ps1 -ProjectPath "./App"
    Compiles only the main App

.EXAMPLE
    ./compile-al-apps.ps1 -ProjectPath "./TestApp"
    Compiles only the TestApp
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    # No project specified - compile both in order
    Write-Host "=== Compiling All AL Applications ===" -ForegroundColor Cyan

    # Compile Main App
    Write-Host "Compiling The Library (main App)..." -ForegroundColor Yellow
    al compile /project:"./App" /packagecachepath:".alpackages"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Compilation failed: ./App (exit code: $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    # Copy compiled main app to .alpackages so TestApp can reference it
    Write-Host "Copying compiled main app to .alpackages..." -ForegroundColor Gray
    Get-ChildItem -Path "./App" -Filter "*.app" -File | Copy-Item -Destination ".alpackages/" -Force

    # Compile Test App
    Write-Host "Compiling The Library Tester (TestApp)..." -ForegroundColor Yellow
    al compile /project:"./TestApp" /packagecachepath:".alpackages"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Compilation failed: ./TestApp (exit code: $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host "All apps compiled successfully" -ForegroundColor Green
}
else {
    # Specific project provided
    Write-Host "=== Compiling AL Application: $ProjectPath ===" -ForegroundColor Cyan

    al compile /project:"$ProjectPath" /packagecachepath:".alpackages"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Compilation failed: $ProjectPath (exit code: $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host "Compilation successful: $ProjectPath" -ForegroundColor Green

    # If we just compiled the App, copy it to .alpackages for TestApp
    if ($ProjectPath -eq "./App" -or $ProjectPath -eq "App") {
        Write-Host "Copying compiled app to .alpackages..." -ForegroundColor Gray
        Get-ChildItem -Path "./App" -Filter "*.app" -File | Copy-Item -Destination ".alpackages/" -Force
    }
}
