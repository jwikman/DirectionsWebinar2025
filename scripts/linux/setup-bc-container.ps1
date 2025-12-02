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

.NOTES
    Requires environment variables:
    - SA_PASSWORD: SQL Server SA password
    - BC_USERNAME: Business Central admin username
    - BC_PASSWORD: Business Central admin user password
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
Write-Host "Cloning BCDevOnLinux repository, branch '$BCDevBranch'..." -ForegroundColor Yellow
git clone --branch $BCDevBranch --depth 1 $BCDevRepo bcdev-temp

# Output last commit information
Write-Host "Repository cloned successfully. Last commit details:" -ForegroundColor Green
Push-Location bcdev-temp
try {
    $commitHash = git rev-parse HEAD
    $commitMessage = git log -1 --pretty=format:"%s"
    Write-Host "  Hash: $commitHash" -ForegroundColor Gray
    Write-Host "  Message: $commitMessage" -ForegroundColor Gray
}
finally {
    Pop-Location
}

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
        Write-Host "No BC artifact URL specified - using BCDevOnLinux defaults (BC 26 Sandbox W1)" -ForegroundColor Yellow
    }

    # Add SA_PASSWORD from environment variable
    if ($env:SA_PASSWORD) {
        Write-Host "Setting SQL SA password from environment" -ForegroundColor Gray
        $envContent += "SA_PASSWORD=$env:SA_PASSWORD"
    }

    # Add ADMIN_USERNAME from environment variable (BC admin username)
    if ($env:BC_USERNAME) {
        Write-Host "Setting BC admin username from environment" -ForegroundColor Gray
        $envContent += "ADMIN_USERNAME=$env:BC_USERNAME"
    }

    # Add ADMIN_PASSWORD from environment variable (BC admin user password)
    if ($env:BC_PASSWORD) {
        Write-Host "Setting BC admin password from environment" -ForegroundColor Gray
        $envContent += "ADMIN_PASSWORD=$env:BC_PASSWORD"
    }

    if ($envContent.Count -gt 0) {
        # Write .env file using Set-Content for better cross-platform compatibility
        Set-Content -Path ".env" -Value $envContent -Encoding utf8NoBOM -Force
        Write-Host "Created .env file with configuration:" -ForegroundColor Cyan
        foreach ($line in $envContent) {
            # Mask passwords in output
            if ($line -match "^SA_PASSWORD=") {
                Write-Host "  SA_PASSWORD=********" -ForegroundColor Gray
            }
            elseif ($line -match "^ADMIN_PASSWORD=") {
                Write-Host "  ADMIN_PASSWORD=********" -ForegroundColor Gray
            }
            else {
                Write-Host "  $line" -ForegroundColor Gray
            }
        }
    }
}
finally {
    Pop-Location
}

Write-Host "Business Central container setup completed successfully" -ForegroundColor Green
Write-Host "Environment is ready. Use start-bc-container.ps1 to build and start the containers." -ForegroundColor Cyan
