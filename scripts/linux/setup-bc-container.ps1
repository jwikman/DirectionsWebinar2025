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
    ./setup-bc-container.ps1 -BCDevRepo "https://github.com/StefanMaron/BCDevOnLinux.git" -BCDevBranch "main" -BCArtifactUrl "https://bcartifacts.azureedge.net/sandbox/27.1/w1"
    ./setup-bc-container.ps1 -BCDevRepo "https://github.com/jwikman/BCDevOnLinux.git" -BCDevBranch "main" -BCArtifactUrl "https://bcartifacts.azureedge.net/sandbox/27.1.41698.42876/w1"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$BCDevRepo,
    [Parameter(Mandatory = $true)]
    [string]$BCDevBranch,
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

# Clean up any existing BC artifacts volume to force fresh download
Write-Host "Cleaning up any existing BC artifacts volume..." -ForegroundColor Yellow
docker volume rm bcdev-temp_bc_artifacts -f 2>$null
Write-Host "✓ BC artifacts volume removed (will be recreated fresh)" -ForegroundColor Green

# Build BC Container with Docker Compose
Write-Host "Building Business Central container..." -ForegroundColor Yellow
Push-Location bcdev-temp
try {
    # Create .env file with BC configuration
    $envContent = @()

    if ($BCArtifactUrl) {
        Write-Host "Using BC Artifact URL: $BCArtifactUrl" -ForegroundColor Cyan

        # Parse the artifact URL to extract version and country
        # Workaround: Extract and set legacy variables BC_VERSION, BC_COUNTRY, BC_TYPE
        # URL format: https://bcartifacts.azureedge.net/<type>/<version>/<country>
        if ($BCArtifactUrl -match '/(?<type>sandbox|onprem)/(?<version>[^/]+)/(?<country>[^/?]+)') {
            $bcType = $matches['type']
            $bcVersion = $matches['version']
            $bcCountry = $matches['country']

            # Capitalize first letter of type
            $bcType = $bcType.Substring(0,1).ToUpper() + $bcType.Substring(1)

            Write-Host "  Parsed - Type: $bcType, Version: $bcVersion, Country: $bcCountry" -ForegroundColor Gray

            # Set legacy variables (workaround for jwikman/BCDevOnLinux cache-artifacts.ps1 bug)
            $envContent += "BC_TYPE=$bcType"
            $envContent += "BC_VERSION=$bcVersion"
            $envContent += "BC_COUNTRY=$bcCountry"

            # Also set BC_ARTIFACT_URL for potential future fix
            $envContent += "BC_ARTIFACT_URL=$BCArtifactUrl"
        }
        else {
            Write-Host "  Warning: Could not parse artifact URL format" -ForegroundColor Yellow
            Write-Host "  Falling back to BC_ARTIFACT_URL only (may not work due to bug in cache-artifacts.ps1)" -ForegroundColor Yellow
            $envContent += "BC_ARTIFACT_URL=$BCArtifactUrl"
        }
    }
    else {
        Write-Host "No BC artifact URL specified - using BCDevOnLinux defaults (BC 26 Sandbox W1)" -ForegroundColor Yellow
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
