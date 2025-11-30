#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Execute AL tests via OData API using the Codeunit Run Request system.

.DESCRIPTION
    This script executes AL test codeunits via the OData API exposed by the
    Codeunit Run Requests API page (page 50002). It provides a stateful
    execution pattern with status tracking.

.PARAMETER BaseUrl
    The base URL of the Business Central instance (e.g., "http://localhost:7049/BC")

.PARAMETER Tenant
    The tenant name (default: "default")

.PARAMETER Username
    Username for authentication (default: "admin")

.PARAMETER Password
    Password for authentication (default: "P@ssw0rd123!")

.PARAMETER CodeunitId
    The ID of the test codeunit to execute (default: 50001 - "Sample Data Tests PPC")

.PARAMETER MaxWaitSeconds
    Maximum time to wait for test execution to complete (default: 300 seconds)

.EXAMPLE
    ./run-tests-odata.ps1 -BaseUrl "http://localhost:7048/BC" -CodeunitId 50001

.NOTES
    API Endpoint: /api/custom/automation/v1.0/codeunitRunRequests
    Uses the state-tracked execution pattern with status monitoring.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BaseUrl = "http://localhost:7048/BC",

    [Parameter(Mandatory=$false)]
    [string]$Tenant = "default",

    [Parameter(Mandatory=$false)]
    [string]$Username = "admin",

    [Parameter(Mandatory=$false)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification='BC container default credentials')]
    [string]$Password = "Admin123!",

    [Parameter(Mandatory=$false)]
    [int]$CodeunitId = 50001,

    [Parameter(Mandatory=$false)]
    [int]$MaxWaitSeconds = 300
)

# Enable strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Build API endpoint
$ApiPath = "/api/custom/automation/v1.0/codeunitRunRequests"
$ApiUrl = "$BaseUrl$ApiPath"

Write-Host "=== AL Test Execution via OData API ===" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host "Tenant: $Tenant" -ForegroundColor Gray
Write-Host "Codeunit ID: $CodeunitId" -ForegroundColor Gray
Write-Host ""

# Diagnostic information
Write-Host "=== DIAGNOSTIC INFORMATION ===" -ForegroundColor Magenta
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "OS: $($PSVersionTable.OS)" -ForegroundColor Gray
Write-Host "Platform: $($PSVersionTable.Platform)" -ForegroundColor Gray
Write-Host "Is Linux: $($IsLinux)" -ForegroundColor Gray
Write-Host "Is Windows: $($IsWindows)" -ForegroundColor Gray
Write-Host ""

# Use hardcoded working base64 credentials (admin:Admin123!)
# Base64 encoding of "admin:Admin123!"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:Admin123!"))

# Headers for API requests
$Headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "Basic $base64AuthInfo"
}

# Function to make HTTP requests with fallback to curl on Linux
function Invoke-BCApiRequest {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Headers,
        [string]$Body = $null,
        [int]$TimeoutSec = 30
    )

    Write-Host "[DEBUG] Invoke-BCApiRequest - Method: $Method, Uri: $Uri" -ForegroundColor Magenta

    # Try Invoke-RestMethod first
    try {
        $params = @{
            Uri = $Uri
            Method = $Method
            Headers = $Headers
            TimeoutSec = $TimeoutSec
        }

        if ($Body) {
            $params.Body = $Body
        }

        # Add Linux-specific parameters
        if ($IsLinux) {
            $params.AllowUnencryptedAuthentication = $true
            $params.SkipHttpErrorCheck = $true
        }

        $response = Invoke-RestMethod @params
        Write-Host "[DEBUG] Invoke-RestMethod succeeded" -ForegroundColor Magenta
        return $response
    }
    catch {
        Write-Host "[WARNING] Invoke-RestMethod failed: $($_.Exception.Message)" -ForegroundColor Yellow

        # On Linux, fall back to curl
        if ($IsLinux) {
            Write-Host "[INFO] Falling back to curl..." -ForegroundColor Yellow

            try {
                $curlArgs = @(
                    "-s"  # Silent
                    "-X", $Method
                    "-u", "admin:Admin123!"
                    "-H", "Content-Type: application/json"
                    "-H", "Accept: application/json"
                )

                if ($Body) {
                    $curlArgs += @("-d", $Body)
                }

                $curlArgs += $Uri

                Write-Host "[DEBUG] Curl command: curl $($curlArgs -join ' ')" -ForegroundColor Magenta

                $curlOutput = & curl @curlArgs 2>&1
                Write-Host "[DEBUG] Curl output (first 500 chars): $($curlOutput.ToString().Substring(0, [Math]::Min(500, $curlOutput.ToString().Length)))" -ForegroundColor Magenta

                # Parse JSON response
                if ($curlOutput) {
                    $response = $curlOutput | ConvertFrom-Json
                    Write-Host "[DEBUG] Curl succeeded, parsed JSON response" -ForegroundColor Magenta
                    return $response
                }
                else {
                    Write-Host "[ERROR] Curl returned empty response" -ForegroundColor Red
                    throw "Empty response from curl"
                }
            }
            catch {
                Write-Host "[ERROR] Curl fallback failed: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
        else {
            # On Windows, just rethrow the original error
            throw
        }
    }
}

try {
    # Pre-flight diagnostics: Check Docker container status
    Write-Host "[DIAGNOSTIC] Checking Docker container status..." -ForegroundColor Magenta
    try {
        $dockerContainers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>&1
        Write-Host "Docker containers:" -ForegroundColor Gray
        Write-Host $dockerContainers -ForegroundColor Gray
        Write-Host ""
    } catch {
        Write-Host "Could not retrieve Docker container info: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Check if BC container is accessible via curl
    Write-Host "[DIAGNOSTIC] Testing BC endpoint with curl..." -ForegroundColor Magenta
    try {
        # Test without auth first
        $curlTestNoAuth = curl -s -o /dev/null -w "%{http_code}" "$BaseUrl/api/v2.0/companies" 2>&1
        Write-Host "Curl test (no auth) result (HTTP status): $curlTestNoAuth" -ForegroundColor Gray

        # Test with auth
        $curlTest = curl -s -o /dev/null -w "%{http_code}" "$BaseUrl/api/v2.0/companies" -u "admin:Admin123!" 2>&1
        Write-Host "Curl test (with admin:Admin123!) result (HTTP status): $curlTest" -ForegroundColor Gray

        # Also try to get actual response with verbose headers
        Write-Host "Curl verbose response:" -ForegroundColor Gray
        $curlResponse = curl -v "$BaseUrl/api/v2.0/companies" -u "admin:Admin123!" 2>&1
        Write-Host $curlResponse -ForegroundColor Gray

        # Try checking if user exists in BC database
        Write-Host ""
        Write-Host "Checking BC user table..." -ForegroundColor Gray
        $bcContainerName = docker ps --filter "name=bc" --format "{{.Names}}" | Select-Object -First 1
        if ($bcContainerName) {
            $sqlCmd = "SELECT [User Name], [User Security ID], State FROM [dbo].[User] WHERE [User Name] = 'admin'"
            $checkUser = docker exec $bcContainerName bash -c "sqlcmd -S sql -U sa -P 'YourStrong!Passw0rd' -d BC -Q `"$sqlCmd`" -C -N" 2>&1
            Write-Host "User check result:" -ForegroundColor Gray
            Write-Host $checkUser -ForegroundColor Gray
        }
        Write-Host ""
    } catch {
        Write-Host "Curl test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }    # Check BC container logs
    Write-Host "[DIAGNOSTIC] Checking BC container logs (last 20 lines)..." -ForegroundColor Magenta
    try {
        # Get BC container name first
        $bcContainerName = docker ps --filter "name=bc" --format "{{.Names}}" | Select-Object -First 1
        if ($bcContainerName) {
            Write-Host "BC Container: $bcContainerName" -ForegroundColor Gray
            $bcLogs = docker logs --tail 20 $bcContainerName 2>&1
            Write-Host $bcLogs -ForegroundColor Gray
        } else {
            Write-Host "No BC container found" -ForegroundColor Yellow
        }
        Write-Host ""
    } catch {
        Write-Host "Could not retrieve BC logs: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Pre-flight check: Test basic API connectivity and get company ID
    Write-Host "[0/5] Testing API connectivity and retrieving company..." -ForegroundColor Yellow
    try {
        $testUrl = "$BaseUrl/api/v2.0/companies"
        Write-Host "[DEBUG] Test URL: $testUrl" -ForegroundColor Magenta
        Write-Host "[DEBUG] Attempting API request..." -ForegroundColor Magenta

        $testResponse = Invoke-BCApiRequest -Uri $testUrl -Method Get -Headers $Headers -TimeoutSec 60

        Write-Host "[DEBUG] Response type: $($testResponse.GetType().FullName)" -ForegroundColor Magenta

        # Check if response is empty or invalid
        if (-not $testResponse -or $testResponse -is [string] -and [string]::IsNullOrWhiteSpace($testResponse)) {
            Write-Host "[ERROR] API returned empty or invalid response" -ForegroundColor Red
            Write-Host "[ERROR] This typically indicates:" -ForegroundColor Yellow
            Write-Host "  - Authentication failure (401)" -ForegroundColor Yellow
            Write-Host "  - BC Server not fully initialized" -ForegroundColor Yellow
            Write-Host "  - API endpoints not available" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "[DEBUG] Raw response: '$testResponse'" -ForegroundColor Magenta
            exit 1
        }

        Write-Host "[DEBUG] Response content (first 500 chars):" -ForegroundColor Magenta
        $responseJson = $testResponse | ConvertTo-Json -Depth 3 -Compress
        Write-Host $responseJson.Substring(0, [Math]::Min(500, $responseJson.Length)) -ForegroundColor Gray
        Write-Host ""

        if ($testResponse.value -and $testResponse.value.Count -gt 0) {
            # Use the first company
            $CompanyId = $testResponse.value[0].id
            $CompanyName = $testResponse.value[0].name
            Write-Host "✓ API is accessible" -ForegroundColor Green
            Write-Host "  Using company: $CompanyName ($CompanyId)" -ForegroundColor Gray
        } else {
            Write-Host "✗ No companies found in BC" -ForegroundColor Red
            Write-Host "[DEBUG] Full response:" -ForegroundColor Magenta
            Write-Host ($testResponse | ConvertTo-Json -Depth 5) -ForegroundColor Gray
            exit 1
        }
    } catch {
        Write-Host "✗ Failed to connect to API" -ForegroundColor Red
        Write-Host "[ERROR] Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "[ERROR] Exception Message: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[ERROR] Stack Trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed

        if ($_.Exception.InnerException) {
            Write-Host "[ERROR] Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }

        if ($_.Exception.Response) {
            Write-Host "[ERROR] HTTP Response Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
            Write-Host "[ERROR] HTTP Response Status Description: $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
        }

        # Additional error details for troubleshooting
        Write-Host "[DEBUG] Error Record:" -ForegroundColor Magenta
        Write-Host ($_ | Format-List * -Force | Out-String) -ForegroundColor Gray

        exit 1
    }

    # Update API URL to include company
    $ApiUrl = "$BaseUrl/api/custom/automation/v1.0/companies($CompanyId)/codeunitRunRequests"
    Write-Host ""

    Write-Host "[1/4] Creating execution request..." -ForegroundColor Yellow

    # Step 1: Create a new Codeunit Run Request
    Write-Host "  Creating request for Codeunit ID: $CodeunitId" -ForegroundColor Gray
    Write-Host "[DEBUG] API URL: $ApiUrl" -ForegroundColor Magenta

    $RequestBody = @{
        CodeunitId = $CodeunitId
    } | ConvertTo-Json

    Write-Host "[DEBUG] Request Body: $RequestBody" -ForegroundColor Magenta

    try {
        $CreateResponse = Invoke-BCApiRequest -Uri $ApiUrl -Method Post -Headers $Headers -Body $RequestBody -TimeoutSec 30

        Write-Host "[DEBUG] Create Response Type: $($CreateResponse.GetType().FullName)" -ForegroundColor Magenta
        Write-Host "[DEBUG] Create Response: $($CreateResponse | ConvertTo-Json -Depth 3 -Compress)" -ForegroundColor Magenta
    } catch {
        Write-Host "[ERROR] Failed to create execution request" -ForegroundColor Red
        Write-Host "[ERROR] Exception: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[ERROR] Stack Trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
        throw
    }

    $RequestId = $CreateResponse.Id
    $RequestUrl = "$ApiUrl($RequestId)"

    Write-Host "✓ Request created with ID: $RequestId" -ForegroundColor Green
    Write-Host "  Status: $($CreateResponse.Status)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "[2/4] Executing codeunit..." -ForegroundColor Yellow

    # Step 2: Execute the codeunit via the runCodeunit action
    $ActionUrl = "$BaseUrl/api/custom/automation/v1.0/companies($CompanyId)/codeunitRunRequests($RequestId)/Microsoft.NAV.runCodeunit"
    Write-Host "[DEBUG] Action URL: $ActionUrl" -ForegroundColor Magenta

    try {
        $ExecuteResponse = Invoke-BCApiRequest -Uri $ActionUrl -Method Post -Headers $Headers -TimeoutSec 60

        Write-Host "[DEBUG] Execute Response: $($ExecuteResponse | ConvertTo-Json -Depth 3 -Compress)" -ForegroundColor Magenta
    } catch {
        Write-Host "[ERROR] Failed to execute codeunit" -ForegroundColor Red
        Write-Host "[ERROR] Exception: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[ERROR] Stack Trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
        throw
    }

    Write-Host "✓ Execution triggered" -ForegroundColor Green
    Write-Host ""

    Write-Host "[3/4] Monitoring execution status..." -ForegroundColor Yellow

    # Step 3: Poll for completion
    $StartTime = Get-Date
    $Completed = $false
    $Status = "Running"
    $LastResult = ""
    $PollCount = 0

    while (-not $Completed) {
        $PollCount++
        $ElapsedSeconds = ((Get-Date) - $StartTime).TotalSeconds

        if ($ElapsedSeconds -gt $MaxWaitSeconds) {
            Write-Host "✗ Timeout: Execution did not complete within $MaxWaitSeconds seconds" -ForegroundColor Red
            exit 1
        }

        # Get current status
        try {
            $StatusResponse = Invoke-BCApiRequest -Uri $RequestUrl -Method Get -Headers $Headers -TimeoutSec 30

            Write-Host "[DEBUG] Poll #$PollCount Response: $($StatusResponse | ConvertTo-Json -Depth 2 -Compress)" -ForegroundColor Magenta
        } catch {
            Write-Host "[ERROR] Poll #$PollCount failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[ERROR] Stack Trace:" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
            throw
        }

        $Status = $StatusResponse.Status
        $LastResult = $StatusResponse.LastResult
        $LastExecutionUTC = $StatusResponse.LastExecutionUTC

        Write-Host "  Poll #$PollCount - Status: $Status (${ElapsedSeconds}s elapsed)" -ForegroundColor Gray

        if ($Status -eq "Finished" -or $Status -eq "Error") {
            $Completed = $true
        } else {
            # Wait 2 seconds before next poll
            Start-Sleep -Seconds 2
        }
    }

    Write-Host ""
    Write-Host "[4/4] Execution Results:" -ForegroundColor Yellow
    Write-Host "  Status: $Status" -ForegroundColor $(if ($Status -eq "Finished") { "Green" } else { "Red" })
    Write-Host "  Result: $LastResult" -ForegroundColor Gray
    Write-Host "  Execution Time (UTC): $LastExecutionUTC" -ForegroundColor Gray
    Write-Host "  Total Wait Time: $([Math]::Round($ElapsedSeconds, 2)) seconds" -ForegroundColor Gray
    Write-Host ""

    # Step 5: Check Log Table via OData
    Write-Host "[5/5] Retrieving execution logs..." -ForegroundColor Yellow

    try {
        # Access the Log Entries API (no filters, just get all entries)
        $LogApiUrl = "$BaseUrl/api/custom/automation/v1.0/companies($CompanyId)/logEntries"
        Write-Host "[DEBUG] Log API URL: $LogApiUrl" -ForegroundColor Magenta

        $LogResponse = Invoke-BCApiRequest -Uri $LogApiUrl -Method Get -Headers $Headers -TimeoutSec 30

        Write-Host "[DEBUG] Log Response Type: $($LogResponse.GetType().FullName)" -ForegroundColor Magenta
        Write-Host "[DEBUG] Log Entry Count: $($LogResponse.value.Count)" -ForegroundColor Magenta

        if ($LogResponse.value -and $LogResponse.value.Count -gt 0) {
            Write-Host "✓ Found $($LogResponse.value.Count) log entries:" -ForegroundColor Green
            $LogResponse.value | ForEach-Object {
                # Handle both types of logs: manual logs (with Message) and test runner logs (with test details)
                if ($_.message -and $_.message -ne "") {
                    # Manual log entry
                    Write-Host "  [Entry $($_.entryNo)] $($_.message)" -ForegroundColor Cyan
                    if ($_.computerName -and $_.computerName -ne "") {
                        Write-Host "    Computer: $($_.computerName)" -ForegroundColor Gray
                    }
                } elseif ($_.codeunitName -and $_.codeunitName -ne "") {
                    # Test runner log entry
                    $statusIcon = if ($_.success) { "✓" } else { "✗" }
                    $statusColor = if ($_.success) { "Green" } else { "Red" }
                    Write-Host "  $statusIcon [Entry $($_.entryNo)] Test: $($_.codeunitName)::$($_.functionName)" -ForegroundColor $statusColor
                    Write-Host "    Codeunit ID: $($_.codeunitId)" -ForegroundColor Gray

                    # Show error details for failed tests
                    if (-not $_.success -and $_.errorMessage -and $_.errorMessage -ne "") {
                        Write-Host "    Error: $($_.errorMessage)" -ForegroundColor Red
                        if ($_.callStack -and $_.callStack -ne "") {
                            Write-Host "    Call Stack:" -ForegroundColor Gray
                            # Display first 3 lines of call stack to keep output manageable
                            $stackLines = $_.callStack -split "`n" | Select-Object -First 3
                            foreach ($line in $stackLines) {
                                Write-Host "      $line" -ForegroundColor DarkGray
                            }
                        }
                    }
                } else {
                    # Fallback for incomplete log entries
                    Write-Host "  [Entry $($_.entryNo)] (no details logged)" -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "  No log entries found" -ForegroundColor Gray
        }
    } catch {
        Write-Host "✗ Could not retrieve logs: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""

    # Exit with appropriate code
    if ($Status -eq "Finished") {
        Write-Host "=== TEST EXECUTION SUCCESSFUL ===" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "=== TEST EXECUTION FAILED ===" -ForegroundColor Red
        Write-Host "Error: $LastResult" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Host ""
    Write-Host "=== FATAL ERROR ===" -ForegroundColor Red
    Write-Host "Error Type: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "Error Message: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode
        Write-Host "HTTP Status Code: $($statusCode.value__)" -ForegroundColor Red

        # Read response body if available
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            $reader.Close()
            if ($responseBody) {
                Write-Host "Response Body: $responseBody" -ForegroundColor Red
            }
        } catch {
            # Ignore errors reading response body
        }
    }

    Write-Host ""
    Write-Host "Troubleshooting Tips:" -ForegroundColor Yellow
    Write-Host "  1. Verify BC container is running: docker ps" -ForegroundColor Gray
    Write-Host "  2. Check credentials match container config" -ForegroundColor Gray
    Write-Host "  3. Verify API endpoint is accessible: curl $BaseUrl/api/v2.0/companies" -ForegroundColor Gray
    Write-Host "  4. Check if extension is published with API page 50002" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Full Error Details:" -ForegroundColor DarkRed
    Write-Host $_ -ForegroundColor DarkRed

    exit 1
}
