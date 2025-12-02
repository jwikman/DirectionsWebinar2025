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
    # Start the container
    docker compose up -d

    # Wait for container to become healthy (can take up to 10 minutes)
    Write-Host "Waiting for BC container to become healthy (this can take up to 10 minutes)..." -ForegroundColor Yellow
    $containerName = (docker compose ps -q | Select-Object -First 1)
    $elapsed = 0
    $healthStatus = ""
    $prevHealthStatus = ""
    $lastLogTimestamp = Get-Date

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
        # Show incremental logs unless Quiet mode is enabled
        if (-not $Quiet) {
            $currentTimestamp = Get-Date
            # Add 1 second overlap to prevent gaps due to timing precision
            $sinceSeconds = [int]($currentTimestamp - $lastLogTimestamp).TotalSeconds + 1

            if ($sinceSeconds -gt 0) {
                $logOutput = docker compose logs --since="${sinceSeconds}s" bc 2>$null
                if ($logOutput) {
                    Write-Host "[BC Container Log - ${elapsed}s]" -ForegroundColor Cyan
                    Write-Host $logOutput
                }

                if ($IncludeSqlLogs) {
                    $sqlLogOutput = docker compose logs --since="${sinceSeconds}s" sql 2>$null
                    if ($sqlLogOutput) {
                        Write-Host "[SQL Server Log - ${elapsed}s]" -ForegroundColor DarkCyan
                        Write-Host $sqlLogOutput
                    }
                }
            }
            $lastLogTimestamp = $currentTimestamp
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
            docker compose logs bc
            if ($IncludeSqlLogs) {
                Write-Host "`nSQL Server logs:" -ForegroundColor Yellow
                docker compose logs sql
            }
        }
        exit 1
    }

    # Check container status
    Write-Host "`nContainer status:" -ForegroundColor Cyan
    docker compose ps

    # Show any trailing logs that weren't printed during the loop
    if (-not $Quiet) {
        $currentTimestamp = Get-Date
        # Add 1 second overlap to prevent gaps due to timing precision
        $sinceSeconds = [int]($currentTimestamp - $lastLogTimestamp).TotalSeconds + 1

        if ($sinceSeconds -gt 0) {
            $logOutput = docker compose logs --since="${sinceSeconds}s" bc 2>$null
            if ($logOutput) {
                Write-Host "`nTrailing BC Container logs:" -ForegroundColor Cyan
                Write-Host $logOutput
            }

            if ($IncludeSqlLogs) {
                $sqlLogOutput = docker compose logs --since="${sinceSeconds}s" sql 2>$null
                if ($sqlLogOutput) {
                    Write-Host "`nTrailing SQL Server logs:" -ForegroundColor DarkCyan
                    Write-Host $sqlLogOutput
                }
            }
        }
    }
}
finally {
    Pop-Location
}

Write-Host "`n✓ BC container started successfully" -ForegroundColor Green
