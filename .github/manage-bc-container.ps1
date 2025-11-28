#Requires -Modules BcContainerHelper

<#
.SYNOPSIS
    Manages The Library Business Central container
.DESCRIPTION
    Provides commands to start, stop, restart, run tests, and manage the BC container
.PARAMETER Action
    Action to perform: Start, Stop, Restart, RunTests, GetInfo, Remove
.PARAMETER containerName
    Name of the BC container (default: "TheLibrary")
.PARAMETER TestSuite
    Test suite to run (optional, runs all tests if not specified)
.EXAMPLE
    .\manage-bc-container.ps1 -Action Start
    .\manage-bc-container.ps1 -Action RunTests
    .\manage-bc-container.ps1 -Action RunTests -TestSuite "Library Tests"
    .\manage-bc-container.ps1 -Action GetInfo
    .\manage-bc-container.ps1 -Action Remove
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Start", "Stop", "Restart", "RunTests", "GetInfo", "Remove", "Logs")]
    [string]$Action,

    [string]$containerName = "TheLibrary",
    [string]$TestSuite = ""
)

$ErrorActionPreference = "Stop"

# Ensure BcContainerHelper is available
if (!(Get-Module -Name BcContainerHelper -ListAvailable)) {
    Write-Error "BcContainerHelper module is not installed. Run: Install-Module BcContainerHelper"
}

Import-Module -Name BcContainerHelper -DisableNameChecking

# Check if container exists
$container = $containerName -in (Get-BcContainers)

if (!$container -and $Action -ne "GetInfo") {
    Write-Error "Container '$containerName' not found. Run .\.github\setup-bc-container.ps1 first."
}

switch ($Action) {
    "Start" {
        Write-Host "Starting container '$containerName'..." -ForegroundColor Yellow
        Start-BcContainer -containerName $containerName
        Wait-BcContainerReady -containerName $containerName

        $webclientUrl = Get-BcContainerServerUrl -containerName $containerName
        Write-Host "✅ Container started successfully!" -ForegroundColor Green
        Write-Host "Web Client: $webclientUrl" -ForegroundColor Cyan
    }

    "Stop" {
        Write-Host "Stopping container '$containerName'..." -ForegroundColor Yellow
        Stop-BcContainer -containerName $containerName
        Write-Host "✅ Container stopped successfully!" -ForegroundColor Green
    }

    "Restart" {
        Write-Host "Restarting container '$containerName'..." -ForegroundColor Yellow
        Restart-BcContainer -containerName $containerName
        Wait-BcContainerReady -containerName $containerName

        $webclientUrl = Get-BcContainerServerUrl -containerName $containerName
        Write-Host "✅ Container restarted successfully!" -ForegroundColor Green
        Write-Host "Web Client: $webclientUrl" -ForegroundColor Cyan
    }

    "RunTests" {
        Write-Host "Running tests in container '$containerName'..." -ForegroundColor Yellow

        # Create test results directory
        $testResultsDir = Join-Path $PSScriptRoot "TestResults"
        if (!(Test-Path $testResultsDir)) {
            New-Item -Path $testResultsDir -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $testResultsFile = Join-Path $testResultsDir "TestResults_$timestamp.xml"
        $testErrorsFile = Join-Path $testResultsDir "TestErrors_$timestamp.log"
        $testSummaryFile = Join-Path $testResultsDir "TestSummary_$timestamp.json"

        try {
            if ($TestSuite) {
                Write-Host "Running test suite: $TestSuite" -ForegroundColor Cyan
                $testResults = Run-TestsInBcContainer -containerName $containerName -testSuite $TestSuite -detailed -XUnitResultFileName $testResultsFile
            } else {
                Write-Host "Running all tests..." -ForegroundColor Cyan
                $testResults = Run-TestsInBcContainer -containerName $containerName -detailed -XUnitResultFileName $testResultsFile
            }

            # Write test errors to file
            $errorContent = @()
            $errorContent += "Test Execution Errors - $timestamp"
            $errorContent += "=" * 50
            $errorContent += ""

            if ($testResults.Tests) {
                $failedTests = $testResults.Tests | Where-Object { $_.Result -eq "FAILURE" -or $_.Result -eq "ERROR" }

                if ($failedTests) {
                    foreach ($test in $failedTests) {
                        $errorContent += "TEST: $($test.Name)"
                        $errorContent += "CODEUNIT: $($test.CodeunitName)"
                        $errorContent += "METHOD: $($test.MethodName)"
                        $errorContent += "RESULT: $($test.Result)"
                        if ($test.ErrorInfo) {
                            $errorContent += "ERROR: $($test.ErrorInfo)"
                        }
                        if ($test.CallStack) {
                            $errorContent += "CALLSTACK:"
                            $errorContent += $test.CallStack
                        }
                        $errorContent += "-" * 40
                        $errorContent += ""
                    }
                } else {
                    $errorContent += "No test errors found."
                }
            } else {
                $errorContent += "No test result details available."
            }

            # Write errors to file
            $errorContent | Out-File -FilePath $testErrorsFile -Encoding UTF8

            # Create test summary JSON
            $summary = @{
                Timestamp = $timestamp
                ContainerName = $containerName
                TestSuite = if ($TestSuite) { $TestSuite } else { "All Tests" }
                TotalTests = $testResults.TotalTests
                PassedTests = $testResults.PassedTests
                FailedTests = $testResults.FailedTests
                SkippedTests = $testResults.SkippedTests
                ExecutionTime = $testResults.ExecutionTime
                ResultsFile = $testResultsFile
                ErrorsFile = $testErrorsFile
                Success = ($testResults.FailedTests -eq 0)
            }

            $summary | ConvertTo-Json -Depth 3 | Out-File -FilePath $testSummaryFile -Encoding UTF8

        } catch {
            # Write exception to error file
            $errorContent = @()
            $errorContent += "Test Execution Exception - $timestamp"
            $errorContent += "=" * 50
            $errorContent += ""
            $errorContent += "EXCEPTION: $($_.Exception.Message)"
            $errorContent += "STACK TRACE:"
            $errorContent += $_.Exception.StackTrace
            $errorContent | Out-File -FilePath $testErrorsFile -Encoding UTF8

            Write-Error "Failed to run tests: $($_.Exception.Message)"
            return
        }

        # Display test results summary
        Write-Host ""
        Write-Host "Test Results Summary:" -ForegroundColor White
        Write-Host "  Total Tests: $($testResults.TotalTests)" -ForegroundColor Cyan
        Write-Host "  Passed: $($testResults.PassedTests)" -ForegroundColor Green
        Write-Host "  Failed: $($testResults.FailedTests)" -ForegroundColor $(if ($testResults.FailedTests -gt 0) { "Red" } else { "Green" })
        Write-Host "  Skipped: $($testResults.SkippedTests)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Test files generated:" -ForegroundColor White
        Write-Host "  Results (XML): $testResultsFile" -ForegroundColor Cyan
        Write-Host "  Errors (Log): $testErrorsFile" -ForegroundColor Cyan
        Write-Host "  Summary (JSON): $testSummaryFile" -ForegroundColor Cyan

        if ($testResults.FailedTests -gt 0) {
            Write-Host ""
            Write-Host "❌ Some tests failed! Check $testErrorsFile for details." -ForegroundColor Red
            exit 1
        } else {
            Write-Host ""
            Write-Host "✅ All tests passed!" -ForegroundColor Green
        }
    }

    "GetInfo" {
        if ($container) {
            $containerInfo = Get-BcContainerNavVersion -containerName $containerName
            $webclientUrl = Get-BcContainerServerUrl -containerName $containerName
            $isRunning = (docker ps --filter "name=$containerName" --format "{{.Names}}") -eq $containerName

            Write-Host ""
            Write-Host "Container Information:" -ForegroundColor White
            Write-Host "  Name: $containerName" -ForegroundColor Cyan
            Write-Host "  Status: $(if ($isRunning) { "Running" } else { "Stopped" })" -ForegroundColor $(if ($isRunning) { "Green" } else { "Red" })
            Write-Host "  Version: $($containerInfo.Version)" -ForegroundColor Cyan
            Write-Host "  Build: $($containerInfo.Build)" -ForegroundColor Cyan
            if ($isRunning) {
                Write-Host "  Web Client: $webclientUrl" -ForegroundColor Cyan
            }

            # Get installed apps
            if ($isRunning) {
                Write-Host ""
                Write-Host "Installed Extensions:" -ForegroundColor White
                $apps = Get-BcContainerAppInfo -containerName $containerName
                $customApps = $apps | Where-Object { $_.Publisher -ne "Microsoft" }
                foreach ($app in $customApps) {
                    Write-Host "  $($app.Name) v$($app.Version) by $($app.Publisher)" -ForegroundColor Cyan
                }
            }
        } else {
            Write-Host "Container '$containerName' not found." -ForegroundColor Red
            Write-Host "Run .\.github\setup-bc-container.ps1 to create it." -ForegroundColor Yellow
        }
    }

    "Remove" {
        Write-Host "Removing container '$containerName'..." -ForegroundColor Yellow
        Write-Host "This will permanently delete the container and all data!" -ForegroundColor Red

        $confirmation = Read-Host "Are you sure? (y/N)"
        if ($confirmation -eq "y" -or $confirmation -eq "Y") {
            Remove-BcContainer -containerName $containerName -Force
            Write-Host "✅ Container removed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
        }
    }

    "Logs" {
        Write-Host "Getting container logs for '$containerName'..." -ForegroundColor Yellow
        Get-BcContainerEventLog -containerName $containerName -doNotOpen
    }
}