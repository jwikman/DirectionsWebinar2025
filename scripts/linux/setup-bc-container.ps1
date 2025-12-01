#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup Business Central container using BCDevOnLinux

.DESCRIPTION
    Clones BCDevOnLinux repository and builds the BC container using Docker Compose

.PARAMETER BCDevRepo
    BCDevOnLinux repository URL (default: https://github.com/StefanMaron/BCDevOnLinux.git)

.PARAMETER BCDevBranch
    BCDevOnLinux repository branch (default: main)

.PARAMETER BCArtifactUrl
    BC Artifact URL to use for the container (mandatory)

.EXAMPLE
    ./setup-bc-container.ps1
    ./setup-bc-container.ps1 -BCDevRepo "https://github.com/StefanMaron/BCDevOnLinux.git" -BCDevBranch "main"
    ./setup-bc-container.ps1 -BCArtifactUrl "https://bcartifacts.azureedge.net/sandbox/27.1/w1"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$BCDevRepo = "https://github.com/StefanMaron/BCDevOnLinux.git",
    [Parameter(Mandatory = $false)]
    [string]$BCDevBranch = "main",
    [Parameter(Mandatory = $true)]
    [string]$BCArtifactUrl
)

$ErrorActionPreference = "Stop"

Write-Host "=== Setting up Business Central Container ===" -ForegroundColor Cyan

# Verify Docker is available
Write-Host "Verifying Docker installation..." -ForegroundColor Yellow
docker --version
docker compose version

# Clone BCDevOnLinux repository
Write-Host "Cloning BCDevOnLinux repository..." -ForegroundColor Yellow
git clone --branch $BCDevBranch --depth 1 $BCDevRepo bcdev-temp

# Pull BC Wine Base Image
Write-Host "Pulling BC Wine base image..." -ForegroundColor Yellow
docker pull stefanmaronbc/bc-wine-base:latest

# Build BC Container with Docker Compose
Write-Host "Building Business Central container..." -ForegroundColor Yellow
Push-Location bcdev-temp
try {
    # Create .env file with BC configuration
    $envContent = @()

    if ($BCArtifactUrl) {
        Write-Host "Using BC Artifact URL: $BCArtifactUrl" -ForegroundColor Cyan
        $envContent += "BC_ARTIFACT_URL=$BCArtifactUrl"
    }
    else {
        Write-Host "No BC artifact URL specified - using BCDevOnLinux defaults" -ForegroundColor Yellow
    }

    # Add SA_PASSWORD from environment if available
    if ($env:SA_PASSWORD) {
        Write-Host "Setting SQL SA password from environment" -ForegroundColor Gray
        $envContent += "SA_PASSWORD=$env:SA_PASSWORD"
    }

    if ($envContent.Count -gt 0) {
        # Remove any existing .env files to ensure clean state
        if (Test-Path ".env") {
            Remove-Item ".env" -Force
            Write-Host "Removed existing .env file" -ForegroundColor Gray
        }
        if (Test-Path ".env.example") {
            Remove-Item ".env.example" -Force
            Write-Host "Removed .env.example file" -ForegroundColor Gray
        }

        # Write .env file using Set-Content for better cross-platform compatibility
        Set-Content -Path ".env" -Value $envContent -Encoding utf8NoBOM -Force
        Write-Host "Created .env file with configuration:" -ForegroundColor Cyan
        foreach ($line in $envContent) {
            # Mask password in output
            if ($line -match "^SA_PASSWORD=") {
                Write-Host "  SA_PASSWORD=********" -ForegroundColor Gray
            }
            else {
                Write-Host "  $line" -ForegroundColor Gray
            }
        }
    }

    docker compose build
}
finally {
    Pop-Location
}

Write-Host "Business Central container setup completed successfully" -ForegroundColor Green
