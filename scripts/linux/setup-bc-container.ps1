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
    [string]$BCDevRepo = "https://github.com/StefanMaron/BCDevOnLinux.git",
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
    # Create .env file with BC version configuration if artifact URL provided
    if ($BCArtifactUrl) {
        Write-Host "Using BC Artifact URL: $BCArtifactUrl" -ForegroundColor Cyan
        "BC_ARTIFACT_URL=$BCArtifactUrl" | Out-File -FilePath ".env" -Encoding utf8
        Write-Host "Created .env file with BC artifact configuration" -ForegroundColor Gray
    }
    else {
        Write-Host "No BC artifact URL specified - using BCDevOnLinux defaults" -ForegroundColor Yellow
    }

    docker compose build
}
finally {
    Pop-Location
}

Write-Host "Business Central container setup completed successfully" -ForegroundColor Green
