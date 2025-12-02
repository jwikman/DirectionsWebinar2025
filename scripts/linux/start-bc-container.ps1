#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start Business Central container and wait for it to become healthy

.DESCRIPTION
    Starts the BC container using Docker Compose and monitors its health status

.PARAMETER MaxWaitSeconds
    Maximum time to wait for container to become healthy in seconds (default: 1200 = 20 minutes)

.PARAMETER IncludeSqlLogs
    Include SQL Server logs in output (default: false). By default, only BC container logs are shown.

.PARAMETER Quiet
    Suppress incremental log output during health check (default: false). Only show logs on failure or completion.

.EXAMPLE
    ./start-bc-container.ps1
    ./start-bc-container.ps1 -MaxWaitSeconds 1200
    ./start-bc-container.ps1 -IncludeSqlLogs
    ./start-bc-container.ps1 -Quiet
#>

param(
    [int]$MaxWaitSeconds = 1200,
    [switch]$IncludeSqlLogs,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Business Central container..." -ForegroundColor Cyan
Push-Location bcdev-temp

try {
    # Build and start the containers
    # The --build flag ensures images are rebuilt if there are changes
    docker compose up --build -d

    # Wait for container to become healthy (can take up to 10 minutes)...
    Write-Host "Waiting for BC container to become healthy (this can take up to 10 minutes)..." -ForegroundColor Yellow
    $containerName = (docker compose ps -q | Select-Object -First 1)

    # Start log streaming in background if not in Quiet mode
    $logJob = $null
    if (-not $Quiet) {
        $services = if ($IncludeSqlLogs) { @("bc", "sql") } else { @("bc") }
        $logJob = Start-Job -ScriptBlock {
            param($services)
            Push-Location $using:PWD
            docker compose logs --follow --timestamps $services
            Pop-Location
        } -ArgumentList (,$services)
    }

    try {
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

            # Output any new log data from background job
            if ($logJob) {
                Receive-Job -Job $logJob
            }

            # Check if container became unhealthy (was starting, now unhealthy)
            if ($healthStatus -eq "unhealthy" -and $prevHealthStatus -ne "unhealthy") {
                Write-Host "⚠ Container became unhealthy" -ForegroundColor Yellow
                docker compose ps
            }

            Write-Host "Container status: $healthStatus (waited ${elapsed}s / ${MaxWaitSeconds}s)" -ForegroundColor Gray
            $prevHealthStatus = $healthStatus
            Start-Sleep -Seconds 10
            $elapsed += 10
        }
    }
    finally {
        # Receive any remaining log output and stop log streaming
        if ($logJob) {
            Receive-Job -Job $logJob
            Stop-Job -Job $logJob
            Remove-Job -Job $logJob
        }
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
        docker compose ps

        # If we weren't showing incremental logs, show them now for debugging
        if ($Quiet) {
            Write-Host "`nBC Container logs:" -ForegroundColor Yellow
            docker compose logs --timestamps bc 2>$null
            if ($IncludeSqlLogs) {
                Write-Host "`nSQL Server logs:" -ForegroundColor Yellow
                docker compose logs --timestamps sql 2>$null
            }
        }
        exit 1
    }

    # Check container status
    Write-Host "`nContainer status:" -ForegroundColor Cyan
    docker compose ps
}
finally {
    Pop-Location
}

Write-Host "`n✓ BC container started successfully" -ForegroundColor Green
