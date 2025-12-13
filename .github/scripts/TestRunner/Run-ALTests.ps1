#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run AL test codeunits using the Business Central Web Client framework.

.DESCRIPTION
    Cross-platform PowerShell script to run Business Central AL tests directly
    using the Microsoft.Dynamics.Framework.UI.Client DLLs. This script is designed
    to work on both Windows and Linux (GitHub Actions).

    Based on BcContainerHelper's test framework but without Docker/Windows dependencies.

.PARAMETER ServiceUrl
    The URL of the Business Central web client service
    Example: "http://localhost:7048/BC/WebClient" or "https://businesscentral.dynamics.com/..."

.PARAMETER Tenant
    Tenant name to use (default: "default")

.PARAMETER CompanyName
    Company name to use for test execution

.PARAMETER Credential
    PSCredential object containing username and password for authentication

.PARAMETER AuthType
    Authentication type: 'Windows', 'NavUserPassword', or 'AAD' (default: 'NavUserPassword')

.PARAMETER TestSuite
    Name of the test suite to run (default: "DEFAULT")

.PARAMETER TestCodeunit
    Name or ID of test codeunit to run. Wildcards supported. Default is "*"

.PARAMETER TestCodeunitRange
    BC-compatible filter string for loading test codeunits (e.g., "50000..50099")

.PARAMETER TestFunction
    Name of test function to run. Wildcards supported. Default is "*"

.PARAMETER ExtensionId
    Run all tests in the app with this extension ID

.PARAMETER TestRunnerCodeunitId
    ID of the test runner codeunit to use (if different from default)

.PARAMETER TestPage
    ID of the test page to use (default: 130455 for BC15+)

.PARAMETER XUnitResultFileName
    Output path for XUnit-compatible XML result file

.PARAMETER JUnitResultFileName
    Output path for JUnit-compatible XML result file

.PARAMETER Detailed
    Include detailed output for all tests (default: true)

.PARAMETER Culture
    Culture to use when running tests (default: "en-US")

.PARAMETER InteractionTimeout
    Timeout for client interactions (default: 24 hours)

.PARAMETER DisabledTests
    Array of disabled tests in format: @( @{ "codeunitName" = "name"; "method" = "*" } )

.PARAMETER ReturnTrueIfAllPassed
    Return $true/$false based on whether all tests passed

.EXAMPLE
    $cred = Get-Credential
    .\Run-ALTests.ps1 -ServiceUrl "http://localhost:7048/BC" -Credential $cred -TestSuite "DEFAULT"

.EXAMPLE
    .\Run-ALTests.ps1 -ServiceUrl "http://localhost:7048/BC" -Credential $cred -ExtensionId "12345678-1234-1234-1234-123456789012"

.NOTES
    Requires the following DLLs in the same directory:
    - Microsoft.Dynamics.Framework.UI.Client.dll
    - Newtonsoft.Json.dll
    - ClientContext.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ServiceUrl,

    [Parameter(Mandatory = $false)]
    [string] $Tenant = "default",

    [Parameter(Mandatory = $false)]
    [string] $CompanyName = "",

    [Parameter(Mandatory = $true)]
    [PSCredential] $Credential,

    [Parameter(Mandatory = $false)]
    [string] $TestSuite = "DEFAULT",

    [Parameter(Mandatory = $false)]
    [string] $TestCodeunit = "*",

    [Parameter(Mandatory = $false)]
    [string] $TestCodeunitRange = "",

    [Parameter(Mandatory = $false)]
    [string] $TestFunction = "*",

    [Parameter(Mandatory = $false)]
    [string] $ExtensionId = "",

    [Parameter(Mandatory = $false)]
    [string] $TestRunnerCodeunitId = "",

    [Parameter(Mandatory = $false)]
    [int] $TestPage = 130455,

    [Parameter(Mandatory = $false)]
    [string] $XUnitResultFileName = "",

    [Parameter(Mandatory = $false)]
    [string] $JUnitResultFileName = "",

    [Parameter(Mandatory = $false)]
    [switch] $Detailed,

    [Parameter(Mandatory = $false)]
    [string] $Culture = "en-US",

    [Parameter(Mandatory = $false)]
    [timespan] $InteractionTimeout = [timespan]::FromHours(24),

    [Parameter(Mandatory = $false)]
    [array] $DisabledTests = @(),

    [Parameter(Mandatory = $false)]
    [switch] $ReturnTrueIfAllPassed
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Determine script directory
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Required file paths
$ClientDllPath = Join-Path $ScriptDir "Microsoft.Dynamics.Framework.UI.Client.dll"
$NewtonSoftDllPath = Join-Path $ScriptDir "Newtonsoft.Json.dll"
$ClientContextPath = Join-Path $ScriptDir "ClientContext.ps1"

# Verify required files exist
$requiredFiles = @(
    @{ Path = $ClientDllPath; Name = "Microsoft.Dynamics.Framework.UI.Client.dll" },
    @{ Path = $NewtonSoftDllPath; Name = "Newtonsoft.Json.dll" },
    @{ Path = $ClientContextPath; Name = "ClientContext.ps1" }
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file.Path)) {
        throw "Required file not found: $($file.Name) at path: $($file.Path)"
    }
}

Write-Host "Loading required assemblies..."

# Load Newtonsoft.Json
try {
    Add-Type -Path $NewtonSoftDllPath -ErrorAction Stop
    Write-Host "  ✓ Loaded Newtonsoft.Json.dll"
}
catch {
    Write-Warning "Failed to load Newtonsoft.Json: $_"
}

# Load AntiSSRF if available (optional)
$antiSSRFdll = Join-Path $ScriptDir 'Microsoft.Internal.AntiSSRF.dll'
if (Test-Path $antiSSRFdll) {
    try {
        Add-Type -Path $antiSSRFdll -ErrorAction SilentlyContinue
        Write-Host "  ✓ Loaded Microsoft.Internal.AntiSSRF.dll"
    }
    catch {
        Write-Verbose "AntiSSRF DLL not loaded (optional)"
    }
}

# Load Client DLL
try {
    Add-Type -Path $ClientDllPath -ErrorAction Stop
    Write-Host "  ✓ Loaded Microsoft.Dynamics.Framework.UI.Client.dll"
}
catch {
    throw "Failed to load Client DLL: $_"
}

# Load ClientContext
Write-Host "Loading ClientContext..."
. $ClientContextPath

#region Helper Functions

function New-TestClientContext {
    param(
        [string] $ServiceUrl,
        [PSCredential] $Credential,
        [timespan] $InteractionTimeout,
        [string] $Culture
    )

    Write-Host "Creating client context..."

    $timezone = ""  # Empty means auto-detect
    $clientContext = [ClientContext]::new($ServiceUrl, $Credential, $InteractionTimeout, $Culture, $timezone)

    Write-Host "  ✓ Client context created successfully"
    return $clientContext
}

function Get-TestsFromPage {
    param(
        [object] $ClientContext,
        [int] $TestPage,
        [string] $TestSuite,
        [string] $TestCodeunit,
        [string] $TestCodeunitRange,
        [string] $ExtensionId,
        [string] $TestRunnerCodeunitId
    )

    Write-Host "Opening test page $TestPage..."
    $form = $ClientContext.OpenForm($TestPage)

    if (-not $form) {
        throw "Cannot open test page $TestPage. Verify the test toolkit is installed."
    }

    # Set test suite
    $suiteControl = $ClientContext.GetControlByName($form, "CurrentSuiteName")
    $ClientContext.SaveValue($suiteControl, $TestSuite)
    Write-Host "  Test Suite: $TestSuite"

    # Set extension ID if specified
    if ($ExtensionId) {
        Write-Host "  Extension ID: $ExtensionId"
        $extensionIdControl = $ClientContext.GetControlByName($form, "ExtensionId")
        $ClientContext.SaveValue($extensionIdControl, $ExtensionId)
    }

    # Set test codeunit range if specified
    if ($TestCodeunitRange) {
        Write-Host "  Test Codeunit Range: $TestCodeunitRange"
        $rangeControl = $ClientContext.GetControlByName($form, "TestCodeunitRangeFilter")
        if ($rangeControl) {
            $ClientContext.SaveValue($rangeControl, $TestCodeunitRange)
        }
    }

    # Set test runner ID if specified
    if ($TestRunnerCodeunitId) {
        Write-Host "  Test Runner ID: $TestRunnerCodeunitId"
        $runnerControl = $ClientContext.GetControlByName($form, "TestRunnerCodeunitId")
        $ClientContext.SaveValue($runnerControl, $TestRunnerCodeunitId)
    }

    # Get the repeater control with test lines
    $repeater = $ClientContext.GetControlByType($form, [Microsoft.Dynamics.Framework.UI.Client.ClientRepeaterControl])

    $tests = @()
    $index = 0

    Write-Host "Collecting tests..."

    while ($true) {
        $ClientContext.SelectFirstRow($repeater)

        if ($index -ge $repeater.Offset -and $index -lt ($repeater.Offset + $repeater.DefaultViewport.Count)) {
            $rowIndex = $index - $repeater.Offset
            $row = $repeater.DefaultViewport[$rowIndex]

            if (-not $row) { break }

            # Extract test information from row
            $nameControl = $row | Where-Object { $_.Name -eq "Name" } | Select-Object -First 1
            $codeunitIdControl = $row | Where-Object { $_.Name -eq "TestCodeunit" } | Select-Object -First 1
            $lineTypeControl = $row | Where-Object { $_.Name -eq "LineType" } | Select-Object -First 1

            if ($nameControl -and $codeunitIdControl) {
                $testName = $nameControl.StringValue
                $codeunitId = $codeunitIdControl.StringValue

                # Filter by test codeunit pattern
                if ($testName -like $TestCodeunit) {
                    $tests += @{
                        Name = $testName
                        CodeunitId = $codeunitId
                        Index = $index
                    }
                    Write-Host "  Found: $testName (ID: $codeunitId)"
                }
            }

            $index++
        }
        else {
            # Need to scroll
            if ($index -ge ($repeater.Offset + $repeater.DefaultViewport.Count)) {
                $ClientContext.ScrollRepeater($repeater, 1)
            }
            else {
                break
            }
        }

        # Safety check to prevent infinite loops
        if ($index -gt 10000) {
            Write-Warning "Safety limit reached while collecting tests"
            break
        }
    }

    $ClientContext.CloseForm($form)

    Write-Host "  ✓ Found $($tests.Count) test codeunit(s)"
    return $tests
}

function Invoke-TestRun {
    param(
        [object] $ClientContext,
        [int] $TestPage,
        [string] $TestSuite,
        [string] $TestCodeunit,
        [string] $TestFunction,
        [array] $DisabledTests,
        [bool] $Detailed
    )

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════"
    Write-Host "Starting Test Execution"
    Write-Host "═══════════════════════════════════════════════════════"
    Write-Host ""

    $form = $ClientContext.OpenForm($TestPage)

    if (-not $form) {
        throw "Cannot open test page $TestPage"
    }

    # Set test suite
    $suiteControl = $ClientContext.GetControlByName($form, "CurrentSuiteName")
    $ClientContext.SaveValue($suiteControl, $TestSuite)

    # Get run action
    $runAction = $ClientContext.GetActionByName($form, "Run")
    if (-not $runAction) {
        $runAction = $ClientContext.GetActionByName($form, "RunSelected")
    }

    if (-not $runAction) {
        throw "Cannot find Run action on test page"
    }

    # Get repeater
    $repeater = $ClientContext.GetControlByType($form, [Microsoft.Dynamics.Framework.UI.Client.ClientRepeaterControl])

    $allTestResults = @()
    $totalTests = 0
    $passedTests = 0
    $failedTests = 0

    # Execute tests
    $startTime = Get-Date

    Write-Host "Executing tests..."
    $ClientContext.InvokeAction($runAction)

    # Wait for tests to complete and collect results
    Start-Sleep -Seconds 2

    # Read results from repeater
    $ClientContext.Refresh($repeater)

    for ($i = 0; $i -lt $repeater.DefaultViewport.Count; $i++) {
        $row = $repeater.DefaultViewport[$i]

        if (-not $row) { continue }

        $nameControl = $row | Where-Object { $_.Name -eq "Name" } | Select-Object -First 1
        $resultControl = $row | Where-Object { $_.Name -eq "Result" } | Select-Object -First 1

        if ($nameControl) {
            $testName = $nameControl.StringValue
            $result = if ($resultControl) { $resultControl.StringValue } else { "Unknown" }

            $totalTests++

            $testResult = @{
                Name = $testName
                Result = $result
                Success = ($result -eq "Success" -or $result -eq "Passed")
            }

            $allTestResults += $testResult

            if ($testResult.Success) {
                $passedTests++
                if ($Detailed) {
                    Write-Host "  ✓ PASS: $testName" -ForegroundColor Green
                }
            }
            else {
                $failedTests++
                Write-Host "  ✗ FAIL: $testName - $result" -ForegroundColor Red
            }
        }
    }

    $ClientContext.CloseForm($form)

    $endTime = Get-Date
    $duration = $endTime - $startTime

    # Print summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════"
    Write-Host "Test Execution Summary"
    Write-Host "═══════════════════════════════════════════════════════"
    Write-Host "Total Tests:  $totalTests"
    Write-Host "Passed:       $passedTests" -ForegroundColor Green
    Write-Host "Failed:       $failedTests" -ForegroundColor Red
    Write-Host "Duration:     $($duration.TotalSeconds) seconds"
    Write-Host "═══════════════════════════════════════════════════════"
    Write-Host ""

    return @{
        TotalTests = $totalTests
        PassedTests = $passedTests
        FailedTests = $failedTests
        Duration = $duration
        AllPassed = ($failedTests -eq 0)
        Results = $allTestResults
    }
}

function Export-TestResultsXUnit {
    param(
        [object] $TestResults,
        [string] $OutputPath
    )

    Write-Host "Exporting XUnit results to: $OutputPath"

    $xml = New-Object System.Xml.XmlDocument
    $assemblies = $xml.CreateElement("assemblies")
    $xml.AppendChild($assemblies) | Out-Null

    $assembly = $xml.CreateElement("assembly")
    $assembly.SetAttribute("name", "AL.Tests")
    $assembly.SetAttribute("total", $TestResults.TotalTests)
    $assembly.SetAttribute("passed", $TestResults.PassedTests)
    $assembly.SetAttribute("failed", $TestResults.FailedTests)
    $assembly.SetAttribute("time", $TestResults.Duration.TotalSeconds)
    $assemblies.AppendChild($assembly) | Out-Null

    $collection = $xml.CreateElement("collection")
    $collection.SetAttribute("name", "Default")
    $collection.SetAttribute("total", $TestResults.TotalTests)
    $collection.SetAttribute("passed", $TestResults.PassedTests)
    $collection.SetAttribute("failed", $TestResults.FailedTests)
    $assembly.AppendChild($collection) | Out-Null

    foreach ($test in $TestResults.Results) {
        $testElement = $xml.CreateElement("test")
        $testElement.SetAttribute("name", $test.Name)
        $testElement.SetAttribute("result", $(if ($test.Success) { "Pass" } else { "Fail" }))
        $collection.AppendChild($testElement) | Out-Null
    }

    $xml.Save($OutputPath)
    Write-Host "  ✓ XUnit results exported"
}

function Export-TestResultsJUnit {
    param(
        [object] $TestResults,
        [string] $OutputPath
    )

    Write-Host "Exporting JUnit results to: $OutputPath"

    $xml = New-Object System.Xml.XmlDocument
    $testsuites = $xml.CreateElement("testsuites")
    $xml.AppendChild($testsuites) | Out-Null

    $testsuite = $xml.CreateElement("testsuite")
    $testsuite.SetAttribute("name", "AL.Tests")
    $testsuite.SetAttribute("tests", $TestResults.TotalTests)
    $testsuite.SetAttribute("failures", $TestResults.FailedTests)
    $testsuite.SetAttribute("time", $TestResults.Duration.TotalSeconds)
    $testsuites.AppendChild($testsuite) | Out-Null

    foreach ($test in $TestResults.Results) {
        $testcase = $xml.CreateElement("testcase")
        $testcase.SetAttribute("name", $test.Name)
        $testcase.SetAttribute("classname", "ALTests")

        if (-not $test.Success) {
            $failure = $xml.CreateElement("failure")
            $failure.SetAttribute("message", $test.Result)
            $testcase.AppendChild($failure) | Out-Null
        }

        $testsuite.AppendChild($testcase) | Out-Null
    }

    $xml.Save($OutputPath)
    Write-Host "  ✓ JUnit results exported"
}

#endregion

#region Main Execution

try {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════"
    Write-Host "Business Central AL Test Runner"
    Write-Host "═══════════════════════════════════════════════════════"
    Write-Host ""

    # Create client context
    $clientContext = New-TestClientContext `
        -ServiceUrl $ServiceUrl `
        -Credential $Credential `
        -InteractionTimeout $InteractionTimeout `
        -Culture $Culture

    # Run tests
    $testResults = Invoke-TestRun `
        -ClientContext $clientContext `
        -TestPage $TestPage `
        -TestSuite $TestSuite `
        -TestCodeunit $TestCodeunit `
        -TestFunction $TestFunction `
        -DisabledTests $DisabledTests `
        -Detailed $Detailed

    # Export results if requested
    if ($XUnitResultFileName) {
        Export-TestResultsXUnit -TestResults $testResults -OutputPath $XUnitResultFileName
    }

    if ($JUnitResultFileName) {
        Export-TestResultsJUnit -TestResults $testResults -OutputPath $JUnitResultFileName
    }

    # Return result if requested
    if ($ReturnTrueIfAllPassed) {
        return $testResults.AllPassed
    }

    # Exit with appropriate code
    if (-not $testResults.AllPassed) {
        Write-Host "Tests failed!" -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "All tests passed!" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "Test execution failed: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
finally {
    if ($clientContext) {
        Write-Host "Cleaning up client context..."
        $clientContext.Dispose()
    }
}

#endregion
