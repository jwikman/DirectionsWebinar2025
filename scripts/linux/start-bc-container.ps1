#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start Business Central container and wait for it to become healthy

.DESCRIPTION
    Starts the BC container using Docker Compose and monitors its health status

.PARAMETER MaxWaitSeconds
    Maximum time to wait for container to become healthy in seconds (default: 1200 = 20 minutes)

.EXAMPLE
    ./start-bc-container.ps1
    ./start-bc-container.ps1 -MaxWaitSeconds 1200
#>

param(
    [int]$MaxWaitSeconds = 1200
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Business Central container..." -ForegroundColor Cyan
Push-Location bcdev-temp

try {
    # Start the container
    docker compose up -d

    # Wait for container to become healthy (can take up to 10 minutes)
    Write-Host "Waiting for BC container to become healthy (this can take up to 10 minutes)..." -ForegroundColor Yellow
    $containerName = (docker compose ps -q | Select-Object -First 1)
    $elapsed = 0
    $healthStatus = ""
    $prevHealthStatus = ""

    while ($elapsed -lt $MaxWaitSeconds) {
        try {
            $healthStatus = docker inspect --format='{{.State.Health.Status}}' $containerName 2>$null
            if (-not $healthStatus) { $healthStatus = "unknown" }
        }
        catch {
            $healthStatus = "unknown"
        }

        if ($healthStatus -eq "healthy") {
            Write-Host "✓ BC container is healthy and ready" -ForegroundColor Green
            break
        }

        # Check if container became unhealthy (was starting, now unhealthy)
        if ($healthStatus -eq "unhealthy" -and $prevHealthStatus -ne "unhealthy") {
            Write-Host "⚠ Container became unhealthy - printing logs for investigation:" -ForegroundColor Yellow
            docker compose ps
            docker compose logs --tail=100
        }

        Write-Host "Container status: $healthStatus (waited ${elapsed}s / ${MaxWaitSeconds}s)" -ForegroundColor Gray
        $prevHealthStatus = $healthStatus
        Start-Sleep -Seconds 10
        $elapsed += 10
    }

    # Final health check after loop completes (in case timeout was reached while healthy)
    try {
        $healthStatus = docker inspect --format='{{.State.Health.Status}}' $containerName 2>$null
        if (-not $healthStatus) { $healthStatus = "unknown" }
    }
    catch {
        $healthStatus = "unknown"
    }

    if ($healthStatus -ne "healthy") {
        Write-Host "ERROR: Container did not become healthy within $MaxWaitSeconds seconds" -ForegroundColor Red
        Write-Host "Final status: $healthStatus" -ForegroundColor Red
        Write-Host "Printing full container logs:" -ForegroundColor Yellow
        docker compose ps
        docker compose logs
        exit 1
    }

    # Check container status
    Write-Host "`nContainer status:" -ForegroundColor Cyan
    docker compose ps
    Write-Host "`nRecent container logs:" -ForegroundColor Cyan
    docker compose logs --tail=20
}
finally {
    Pop-Location
}

Write-Host "`n✓ BC container started successfully" -ForegroundColor Green
