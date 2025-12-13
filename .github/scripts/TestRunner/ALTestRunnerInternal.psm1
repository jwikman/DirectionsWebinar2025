function Run-AlTestsInternal
(
    [string] $TestSuite = $script:DefaultTestSuite,
    [string] $TestCodeunitsRange = "",
    [string] $TestProcedureRange = "",
    [string] $ExtensionId = "",
    [ValidateSet('None','Disabled','Codeunit','Function')]
    [string] $RequiredTestIsolation = "None",
    [string] $TestType,
    [int] $TestRunnerId = $global:DefaultTestRunner,
    [ValidateSet('Windows','NavUserPassword','AAD')]
    [string] $AutorizationType = $script:DefaultAuthorizationType,
    [string] $TestPage = $global:DefaultTestPage,
    [switch] $DisableSSLVerification,
    [Parameter(Mandatory=$true)]
    [string] $ServiceUrl,
    [Parameter(Mandatory=$false)]
    [pscredential] $Credential,
    [bool] $Detailed = $true,
    [array] $DisabledTests = @(),
    [ValidateSet('Disabled', 'PerRun', 'PerCodeunit', 'PerTest')]
    [string] $CodeCoverageTrackingType = 'Disabled',
    [ValidateSet('Disabled','PerCodeunit','PerTest')]
    [string] $ProduceCodeCoverageMap = 'Disabled',
    [string] $CodeCoverageOutputPath = "$PSScriptRoot\CodeCoverage",
    [string] $CodeCoverageExporterId,
    [switch] $CodeCoverageTrackAllSessions,
    [string] $CodeCoverageFilePrefix,
    [bool] $StabilityRun
)
{
    $ErrorActionPreference = $script:DefaultErrorActionPreference
   
    Setup-TestRun -DisableSSLVerification:$DisableSSLVerification -AutorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl -TestSuite $TestSuite `
        -TestCodeunitsRange $TestCodeunitsRange -TestProcedureRange $TestProcedureRange -ExtensionId $ExtensionId -RequiredTestIsolation $RequiredTestIsolation -TestType $TestType `
        -TestRunnerId $TestRunnerId -TestPage $TestPage -DisabledTests $DisabledTests -CodeCoverageTrackingType $CodeCoverageTrackingType -CodeCoverageTrackAllSessions:$CodeCoverageTrackAllSessions -CodeCoverageOutputPath $CodeCoverageOutputPath -CodeCoverageExporterId $CodeCoverageExporterId -ProduceCodeCoverageMap $ProduceCodeCoverageMap -StabilityRun $StabilityRun
            
    $testRunResults = New-Object System.Collections.ArrayList 
    $testResult = ''
    $numberOfUnexpectedFailures = 0;

    do
    {
        try
        {
            $testStartTime = $(Get-Date)
            $testResult = Run-NextTest -DisableSSLVerification:$DisableSSLVerification -AutorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl -TestSuite $TestSuite
            if($testResult -eq $script:AllTestsExecutedResult)
            {
                return [Array]$testRunResults
            }
 
            $testRunResultObject = ConvertFrom-Json $testResult
            if($CodeCoverageTrackingType -ne 'Disabled') {
                $null = CollectCoverageResults -TrackingType $CodeCoverageTrackingType -OutputPath $CodeCoverageOutputPath -DisableSSLVerification:$DisableSSLVerification -AutorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl -CodeCoverageFilePrefix $CodeCoverageFilePrefix
            }
       }
        catch
        {
            $numberOfUnexpectedFailures++

            $stackTrace = $_.Exception.StackTrace + "Script stack trace: " + $_.ScriptStackTrace 
            $testMethodResult = @{
                method = "Unexpected Failure"
                codeUnit = "Unexpected Failure"
                startTime = $testStartTime.ToString($script:DateTimeFormat)
                finishTime = ($(Get-Date).ToString($script:DateTimeFormat))
                result = $script:FailureTestResultType
                message = $_.Exception.Message
                stackTrace = $stackTrace
            }

            $testRunResultObject = @{
                name = "Unexpected Failure"
                codeUnit = "UnexpectedFailure"
                startTime = $testStartTime.ToString($script:DateTimeFormat)
                finishTime = ($(Get-Date).ToString($script:DateTimeFormat))
                result = $script:FailureTestResultType
                testResults = @($testMethodResult)
            }
        }
        
        $testRunResults.Add($testRunResultObject) > $null
        if($Detailed)
        {
            Print-TestResults -TestRunResultObject $testRunResultObject
        }
    }
    until((!$testRunResultObject) -or ($NumberOfUnexpectedFailuresBeforeAborting -lt $numberOfUnexpectedFailures))

    throw "Expected to end the test execution, something went wrong with returning test results."      
}

function CollectCoverageResults {
    param (
        [ValidateSet('PerRun', 'PerCodeunit', 'PerTest')]
        [string] $TrackingType,
        [string] $OutputPath,
        [switch] $DisableSSLVerification,
        [ValidateSet('Windows','NavUserPassword','AAD')]
        [string] $AutorizationType = $script:DefaultAuthorizationType,
        [Parameter(Mandatory=$false)]
        [pscredential] $Credential,
        [Parameter(Mandatory=$true)]
        [string] $ServiceUrl,
        [string] $CodeCoverageFilePrefix
    )
    try{
        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl
        $form = Open-TestForm -TestPage $TestPage -ClientContext $clientContext
        do {
            $clientContext.InvokeAction($clientContext.GetActionByName($form, "GetCodeCoverage"))

            $CCResultControl = $clientContext.GetControlByName($form, "CCResultsCSVText")
            $CCInfoControl = $clientContext.GetControlByName($form, "CCInfo")
            $CCResult = $CCResultControl.StringValue
            $CCInfo = $CCInfoControl.StringValue
            if($CCInfo -ne $script:CCCollectedResult){
                $CCInfo = $CCInfo -replace ",","-"
                $CCOutputFilename = $CodeCoverageFilePrefix +"_$CCInfo.dat"
                Write-Host "Storing coverage results of $CCCodeunitId in:  $OutputPath\$CCOutputFilename"
                Set-Content -Path "$OutputPath\$CCOutputFilename" -Value $CCResult
            }
        } while ($CCInfo -ne $script:CCCollectedResult)
       
        if($ProduceCodeCoverageMap -ne 'Disabled') {
            $codeCoverageMapPath = Join-Path $OutputPath "TestCoverageMap"
            SaveCodeCoverageMap -OutputPath $codeCoverageMapPath  -DisableSSLVerification:$DisableSSLVerification -AutorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl
        }

        $clientContext.CloseForm($form)
    }
    finally{
        if($clientContext){
            $clientContext.Dispose()
        }
    }
}

function SaveCodeCoverageMap {
    param (
        [string] $OutputPath,
        [switch] $DisableSSLVerification,
        [ValidateSet('Windows','NavUserPassword','AAD')]
        [string] $AutorizationType = $script:DefaultAuthorizationType,
        [Parameter(Mandatory=$false)]
        [pscredential] $Credential,
        [Parameter(Mandatory=$true)]
        [string] $ServiceUrl
    )
    try{
        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl
        $form = Open-TestForm -TestPage $TestPage -ClientContext $clientContext

        $clientContext.InvokeAction($clientContext.GetActionByName($form, "GetCodeCoverageMap"))

        $CCResultControl = $clientContext.GetControlByName($form, "CCMapCSVText")
        $CCMap = $CCResultControl.StringValue

        if (-not (Test-Path $OutputPath))
        {
            New-Item $OutputPath -ItemType Directory
        }
        
        $codeCoverageMapFileName = Join-Path $codeCoverageMapPath "TestCoverageMap.txt"
        if (-not (Test-Path $codeCoverageMapFileName))
        {
            New-Item $codeCoverageMapFileName -ItemType File
        }

        Add-Content -Path $codeCoverageMapFileName -Value $CCMap

        $clientContext.CloseForm($form)
    }
    finally{
        if($clientContext){
            $clientContext.Dispose()
        }
    }
}

function Print-TestResults
(
    $TestRunResultObject
)
{              
    $startTime = Convert-ResultStringToDateTimeSafe -DateTimeString $TestRunResultObject.startTime
    $finishTime = Convert-ResultStringToDateTimeSafe -DateTimeString $TestRunResultObject.finishTime
    $duration = $finishTime.Subtract($startTime)
    $durationSeconds = [Math]::Round($duration.TotalSeconds,3)

    switch($TestRunResultObject.result)
    {
        $script:SuccessTestResultType
        {
            Write-Host -ForegroundColor Green "Success - Codeunit $($TestRunResultObject.name) - Duration $durationSeconds seconds"
            break;
        }
        $script:FailureTestResultType
        {
            Write-Host -ForegroundColor Red "Failure - Codeunit $($TestRunResultObject.name) -  Duration $durationSeconds seconds"
            break;
        }
        default
        {
            if($codeUnitId -ne "0")
            {
                Write-Host -ForegroundColor Yellow "No tests were executed - Codeunit $"
            }
        }
    }

    if($TestRunResultObject.testResults)
    {
        foreach($testFunctionResult in $TestRunResultObject.testResults)
        {
            $durationSeconds = 0;
            $methodName = $testFunctionResult.method

            if($testFunctionResult.result -ne $script:SkippedTestResultType)
            {
                $startTime = Convert-ResultStringToDateTimeSafe -DateTimeString $testFunctionResult.startTime
                $finishTime = Convert-ResultStringToDateTimeSafe -DateTimeString $testFunctionResult.finishTime
                $duration = $finishTime.Subtract($startTime)
                $durationSeconds = [Math]::Round($duration.TotalSeconds,3)
            }

            switch($testFunctionResult.result)
            {
                $script:SuccessTestResultType
                {
                    Write-Host -ForegroundColor Green "   Success - Test method: $methodName - Duration $durationSeconds seconds)"
                    break;
                }
                $script:FailureTestResultType
                {
                    $callStack = $testFunctionResult.stackTrace
                    Write-Host -ForegroundColor Red "   Failure - Test method: $methodName - Duration $durationSeconds seconds"
                    Write-Host -ForegroundColor Red "      Error:"
                    Write-Host -ForegroundColor Red "         $($testFunctionResult.message)"
                    Write-Host -ForegroundColor Red "      Call Stack:"                    
                    if($callStack)
                    {
                        Write-Host -ForegroundColor Red "         $($callStack.Replace(';',"`n         "))"
                    }
                    break;
                }
                $script:SkippedTestResultType
                {
                    Write-Host -ForegroundColor Yellow "   Skipped - Test method: $methodName"
                    break;
                }
            }
        }
    }            
}

function Setup-TestRun
(
    [switch] $DisableSSLVerification,
    [ValidateSet('Windows','NavUserPassword','AAD')]
    [string] $AutorizationType = $script:DefaultAuthorizationType,
    [Parameter(Mandatory=$false)]
    [pscredential] $Credential,
    [Parameter(Mandatory=$true)]
    [string] $ServiceUrl,
    [string] $TestSuite = $script:DefaultTestSuite,
    [string] $TestCodeunitsRange = "",
    [string] $TestProcedureRange = "",
    [string] $ExtensionId = "",
    [ValidateSet('None','Disabled','Codeunit','Function')]
    [string] $RequiredTestIsolation = "None",
    [string] $TestType,
    [int] $TestRunnerId = $global:DefaultTestRunner,
    [string] $TestPage = $global:DefaultTestPage,
    [array] $DisabledTests = @(),
    [ValidateSet('Disabled', 'PerRun', 'PerCodeunit', 'PerTest')]
    [string] $CodeCoverageTrackingType = 'Disabled',
    [ValidateSet('Disabled','PerCodeunit','PerTest')]
    [string] $ProduceCodeCoverageMap = 'Disabled',
    [string] $CodeCoverageOutputPath = "$PSScriptRoot\CodeCoverage",
    [string] $CodeCoverageExporterId,
    [switch] $CodeCoverageTrackAllSessions,
    [bool] $StabilityRun
)
{
    Write-Log "Setting up test run: $CodeCoverageTrackingType - $CodeCoverageOutputPath"
    if($CodeCoverageTrackingType -ne 'Disabled')
    {
        if (-not (Test-Path -Path $CodeCoverageOutputPath))
        {
            $null = New-Item -Path $CodeCoverageOutputPath -ItemType Directory
        }
    }

    try
    {
        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl 

        $form = Open-TestForm -TestPage $TestPage -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AutorizationType -ClientContext $clientContext
        Set-TestSuite -TestSuite $TestSuite -ClientContext $clientContext -Form $form
        Set-ExtensionId -ExtensionId $ExtensionId -Form $form -ClientContext $clientContext
        if (![string]::IsNullOrEmpty($TestType)) {
            Set-RequiredTestIsolation -RequiredTestIsolation $RequiredTestIsolation -Form $form -ClientContext $clientContext
            Set-TestType -TestType $TestType -Form $form -ClientContext $clientContext
        }
        Set-TestCodeunits -TestCodeunitsFilter $TestCodeunitsRange -Form $form -ClientContext $clientContext
        Set-TestProcedures -Filter $TestProcedureRange -Form $form $ClientContext $clientContext
        Set-TestRunner -TestRunnerId $TestRunnerId -Form $form -ClientContext $clientContext
        Set-RunFalseOnDisabledTests -DisabledTests $DisabledTests -Form $form -ClientContext $clientContext
        Set-StabilityRun -StabilityRun $StabilityRun -Form $form -ClientContext $clientContext
        Clear-TestResults -Form $form -ClientContext $clientContext
        if($CodeCoverageTrackingType -ne 'Disabled'){
            Set-CCTrackingType -Value $CodeCoverageTrackingType -Form $form -ClientContext $clientContext
            Set-CCTrackAllSessions -Value:$CodeCoverageTrackAllSessions -Form $form -ClientContext $clientContext
            Set-CCExporterID -Value $CodeCoverageExporterId -Form $form -ClientContext $clientContext
            Clear-CCResults -Form $form -ClientContext $clientContext
            Set-CCProduceCodeCoverageMap -Value $ProduceCodeCoverageMap -Form $form -ClientContext $clientContext
        }
        $clientContext.CloseForm($form)
    }
    finally
    {
        if($clientContext)
        {
            $clientContext.Dispose()
        }
        Write-Log "Complete Test Setup"
    }
}

function Run-NextTest
(
    [switch] $DisableSSLVerification,
    [ValidateSet('Windows','NavUserPassword','AAD')]
    [string] $AutorizationType = $script:DefaultAuthorizationType,
    [Parameter(Mandatory=$false)]
    [pscredential] $Credential,
    [Parameter(Mandatory=$true)]
    [string] $ServiceUrl,
    [string] $TestSuite = $script:DefaultTestSuite
)
{
    try
    {
        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AutorizationType -Credential $Credential -ServiceUrl $ServiceUrl
        $form = Open-TestForm -TestPage $TestPage -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AutorizationType -ClientContext $clientContext
        if($TestSuite -ne $script:DefaultTestSuite)
        {
            Set-TestSuite -TestSuite $TestSuite -ClientContext $clientContext -Form $form
        }

        $clientContext.InvokeAction($clientContext.GetActionByName($form, "RunNextTest"))
        
        $testResultControl = $clientContext.GetControlByName($form, "TestResultJson")
        $testResultJson = $testResultControl.StringValue
        $clientContext.CloseForm($form)
        return $testResultJson
    }
    finally
    {
        if($clientContext)
        {
            $clientContext.Dispose()
        }
    } 
}

function Open-ClientSessionWithWait
(
    [ValidateSet('Windows','NavUserPassword','AAD')]
    [string] $AuthorizationType = $script:DefaultAuthorizationType,
    [switch] $DisableSSLVerification,
    [string] $ServiceUrl,
    [pscredential] $Credential,
    [int] $ClientSessionTimeout = 20,
    [timespan] $TransactionTimeout = $script:DefaultTransactionTimeout,
    [string] $Culture = $script:DefaultCulture
)
{
        $lastErrorMessage = ""
        while(($ClientSessionTimeout -gt 0))
        {
            try
            {
                $clientContext = Open-ClientSession -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AuthorizationType -Credential $Credential -ServiceUrl $ServiceUrl -TransactionTimeout $TransactionTimeout -Culture $Culture
                return $clientContext
            }
            catch
            {
                Start-Sleep -Seconds 1
                $ClientSessionTimeout--
                $lastErrorMessage = $_.Exception.Message
            }
        }

        throw "Could not open the client session. Check if the web server is running and you can log in. Last error: $lastErrorMessage"
}

function Set-TestCodeunits
(
    [string] $TestCodeunitsFilter,
    [ClientContext] $ClientContext,
    $Form
)
{
    if(!$TestCodeunitsFilter)
    {
        return
    }

    $testCodeunitRangeFilterControl = $ClientContext.GetControlByName($Form, "TestCodeunitRangeFilter")
    $ClientContext.SaveValue($testCodeunitRangeFilterControl, $TestCodeunitsFilter)
}

function Set-TestRunner
(
    [int] $TestRunnerId,
    [ClientContext] $ClientContext,
    $Form
)
{
    if(!$TestRunnerId)
    {
        return
    }

    $testRunnerCodeunitIdControl = $ClientContext.GetControlByName($Form, "TestRunnerCodeunitId")
    $ClientContext.SaveValue($testRunnerCodeunitIdControl, $TestRunnerId)
}

function Clear-TestResults
(
    [ClientContext] $ClientContext,
    $Form
)
{
    $ClientContext.InvokeAction($ClientContext.GetActionByName($Form, "ClearTestResults"))
}

function Set-ExtensionId
(
    [string] $ExtensionId,
    [ClientContext] $ClientContext,
    $Form
)
{
    if(!$ExtensionId)
    {
        return
    }

    $extensionIdControl = $ClientContext.GetControlByName($Form, "ExtensionId")
    $ClientContext.SaveValue($extensionIdControl, $ExtensionId)
}

function Set-RequiredTestIsolation {
    param (
        [ValidateSet('None','Disabled','Codeunit','Function')]
        [string] $RequiredTestIsolation = "None",
        [ClientContext] $ClientContext,
        $Form
    )
    $TestIsolationValues = @{
        None = 0
        Disabled = 1
        Codeunit = 2
        Function = 3
    }
    $testIsolationControl = $ClientContext.GetControlByName($Form, "RequiredTestIsolation")
    $ClientContext.SaveValue($testIsolationControl, $TestIsolationValues[$RequiredTestIsolation])
}

function Set-TestType {
    param (
        [ValidateSet("UnitTest","IntegrationTest","Uncategorized")]
        [string] $TestType,
        [ClientContext] $ClientContext,
        $Form
    )
    $TypeValues = @{    
        UnitTest = 1
        IntegrationTest = 2
        Uncategorized = 3
    }
    $testTypeControl = $ClientContext.GetControlByName($Form, "TestType")
    $ClientContext.SaveValue($testTypeControl, $TypeValues[$TestType])
}

function Set-TestSuite
(
    [string] $TestSuite = $script:DefaultTestSuite,
    [ClientContext] $ClientContext,
    $Form
)
{
    $suiteControl = $ClientContext.GetControlByName($Form, "CurrentSuiteName")
    $ClientContext.SaveValue($suiteControl, $TestSuite)
}

function Set-CCTrackingType
{
    param (
        [ValidateSet('Disabled', 'PerRun', 'PerCodeunit', 'PerTest')]
        [string] $Value,
        [ClientContext] $ClientContext,
        $Form
    )
    $TypeValues = @{
        Disabled = 0
        PerRun = 1
        PerCodeunit=2
        PerTest=3
    }
    $suiteControl = $ClientContext.GetControlByName($Form, "CCTrackingType")
    $ClientContext.SaveValue($suiteControl, $TypeValues[$Value])
}

function Set-CCTrackAllSessions
{
    param (
        [switch] $Value,
        [ClientContext] $ClientContext,
        $Form
    )
    if($Value){
        $suiteControl = $ClientContext.GetControlByName($Form, "CCTrackAllSessions");
        $ClientContext.SaveValue($suiteControl, $Value)
    }
}

function Set-CCExporterID
{
    param (
        [string] $Value,
        [ClientContext] $ClientContext,
        $Form
    )
    if($Value){
        $suiteControl = $ClientContext.GetControlByName($Form, "CCExporterID");
        $ClientContext.SaveValue($suiteControl, $Value)
    }
}

function Set-CCProduceCodeCoverageMap
{

    param (
        [ValidateSet('Disabled', 'PerCodeunit', 'PerTest')]
        [string] $Value,
        [ClientContext] $ClientContext,
        $Form
    )
    $TypeValues = @{
        Disabled = 0
        PerCodeunit = 1
        PerTest=2
    }
    $suiteControl = $ClientContext.GetControlByName($Form, "CCMap")
    $ClientContext.SaveValue($suiteControl, $TypeValues[$Value])
}

function Set-TestProcedures
{
    param (
        [string] $Filter,
        [ClientContext] $ClientContext,
        $Form
    )
    $Control = $ClientContext.GetControlByName($Form, "TestProcedureRangeFilter")
    $ClientContext.SaveValue($Control, $Filter)
}

function Clear-CCResults
{
    param (
        [ClientContext] $ClientContext,
        $Form
    )
    $ClientContext.InvokeAction($ClientContext.GetActionByName($Form, "ClearCodeCoverage"))
}
function Set-StabilityRun
(
    [bool] $StabilityRun,
    [ClientContext] $ClientContext,
    $Form
)
{
    $stabilityRunControl = $ClientContext.GetControlByName($Form, "StabilityRun")
    $ClientContext.SaveValue($stabilityRunControl, $StabilityRun)
}

function Set-RunFalseOnDisabledTests
(
    [ClientContext] $ClientContext,
    [array] $DisabledTests,
    $Form
)
{
    if(!$DisabledTests)
    {
        return
    }

    foreach($disabledTestMethod in $DisabledTests)
    {
        $testKey = $disabledTestMethod.codeunitName + "," + $disabledTestMethod.method
        $removeTestMethodControl = $ClientContext.GetControlByName($Form, "DisableTestMethod")
        $ClientContext.SaveValue($removeTestMethodControl, $testKey)
    }
}

function Open-TestForm(
    [int] $TestPage = $global:DefaultTestPage,
    [ClientContext] $ClientContext
)
{ 
    $form = $ClientContext.OpenForm($TestPage)
    if (!$form) 
    {
        throw "Cannot open page $TestPage. Verify if the test tool and test objects are imported and can be opened manually."
    }

    return $form;
}

function Open-ClientSession
(
    [switch] $DisableSSLVerification,
    [ValidateSet('Windows','NavUserPassword','AAD')]
    [string] $AuthorizationType,
    [Parameter(Mandatory=$false)]
    [pscredential] $Credential,
    [Parameter(Mandatory=$true)]
    [string] $ServiceUrl,
    [string] $Culture = $script:DefaultCulture,
    [timespan] $TransactionTimeout = $script:DefaultTransactionTimeout,
    [timespan] $TcpKeepActive = $script:DefaultTcpKeepActive
)
{
    [System.Net.ServicePointManager]::SetTcpKeepAlive($true, [int]$TcpKeepActive.TotalMilliseconds, [int]$TcpKeepActive.TotalMilliseconds)

    if($DisableSSLVerification)
    {
        Disable-SslVerification
    }

    switch ($AuthorizationType)
    {
        "Windows" 
        {
            $clientContext = [ClientContext]::new($ServiceUrl, $TransactionTimeout, $Culture)
            break;
        }
        "NavUserPassword" 
        {
            if ($Credential -eq $null -or $Credential -eq [System.Management.Automation.PSCredential]::Empty) 
            {
                throw "You need to specify credentials if using NavUserPassword authentication"
            }
        
            $clientContext = [ClientContext]::new($ServiceUrl, $Credential, $TransactionTimeout, $Culture)
            break;
        }
        "AAD"
        {
            $AadTokenProvider = $global:AadTokenProvider
            if ($AadTokenProvider -eq $null) 
            {
                throw "You need to specify the AadTokenProvider for obtaining the token if using AAD authentication"
            }

            $token = $AadTokenProvider.GetToken($Credential)
            $tokenCredential = [Microsoft.Dynamics.Framework.UI.Client.TokenCredential]::new($token)
            $clientContext = [ClientContext]::new($ServiceUrl, $tokenCredential, $TransactionTimeout, $Culture)
        }
    }

    return $clientContext;
}

function Disable-SslVerification
{
    if (-not ([System.Management.Automation.PSTypeName]"SslVerification").Type)
    {
        Add-Type -TypeDefinition  @"
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class SslVerification
{
    private static bool ValidationCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors) { return true; }
    public static void Disable() { System.Net.ServicePointManager.ServerCertificateValidationCallback = ValidationCallback; }
    public static void Enable()  { System.Net.ServicePointManager.ServerCertificateValidationCallback = null; }
}
"@
    }
    [SslVerification]::Disable()
}

function Enable-SslVerification
{
    if (([System.Management.Automation.PSTypeName]"SslVerification").Type)
    {
        [SslVerification]::Enable()
    }
}


function Convert-ResultStringToDateTimeSafe([string] $DateTimeString)
{
    [datetime]$parsedDateTime = New-Object DateTime
    
    try
    {
        [datetime]$parsedDateTime = [datetime]$DateTimeString
    }
    catch
    {
        Write-Host -ForegroundColor Red "Failed parsing DateTime: $DateTimeString"
    }

    return $parsedDateTime
}

if(!$script:TypesLoaded)
{
    Add-type -Path "$PSScriptRoot\Microsoft.Dynamics.Framework.UI.Client.dll"
    Add-type -Path "$PSScriptRoot\Microsoft.Internal.AntiSSRF.dll"
    Add-type -Path "$PSScriptRoot\NewtonSoft.Json.dll"
    
    $clientContextScriptPath = Join-Path $PSScriptRoot "ClientContext.ps1"
    . "$clientContextScriptPath"
}

$script:TypesLoaded = $true;

$script:ActiveDirectoryDllsLoaded = $false;
$script:DateTimeFormat = 's';

# Console test tool
$global:DefaultTestPage = 130455;
$global:AadTokenProvider = $null

# Test Isolation Disabled
$global:TestRunnerIsolationCodeunit = 130450
$global:TestRunnerIsolationDisabled = 130451
$global:DefaultTestRunner = $global:TestRunnerIsolationCodeunit
$global:TestRunnerAppId = "23de40a6-dfe8-4f80-80db-d70f83ce8caf"

$script:CodeunitLineType = '0'
$script:FunctionLineType = '1'

$script:FailureTestResultType = '1';
$script:SuccessTestResultType = '2';
$script:SkippedTestResultType = '3';

$script:NumberOfUnexpectedFailuresBeforeAborting = 50;

$script:DefaultAuthorizationType = 'NavUserPassword'
$script:DefaultTestSuite = 'DEFAULT'
$script:DefaultErrorActionPreference = 'Stop'

$script:DefaultTcpKeepActive = [timespan]::FromMinutes(2);
$script:DefaultTransactionTimeout = [timespan]::FromMinutes(10);
$script:DefaultCulture = "en-US";

$script:AllTestsExecutedResult = "All tests executed."
$script:CCCollectedResult = "Done."
Export-ModuleMember -Function Run-AlTestsInternal,Open-ClientSessionWithWait, Open-TestForm, Open-ClientSession
# SIG # Begin signature block
# MIIoDAYJKoZIhvcNAQcCoIIn/TCCJ/kCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBKIDSqOm9oUE5X
# OIY+HhcPvHEV7QPv41mMaq8LxValSqCCDXYwggX0MIID3KADAgECAhMzAAAEhV6Z
# 7A5ZL83XAAAAAASFMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjUwNjE5MTgyMTM3WhcNMjYwNjE3MTgyMTM3WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDASkh1cpvuUqfbqxele7LCSHEamVNBfFE4uY1FkGsAdUF/vnjpE1dnAD9vMOqy
# 5ZO49ILhP4jiP/P2Pn9ao+5TDtKmcQ+pZdzbG7t43yRXJC3nXvTGQroodPi9USQi
# 9rI+0gwuXRKBII7L+k3kMkKLmFrsWUjzgXVCLYa6ZH7BCALAcJWZTwWPoiT4HpqQ
# hJcYLB7pfetAVCeBEVZD8itKQ6QA5/LQR+9X6dlSj4Vxta4JnpxvgSrkjXCz+tlJ
# 67ABZ551lw23RWU1uyfgCfEFhBfiyPR2WSjskPl9ap6qrf8fNQ1sGYun2p4JdXxe
# UAKf1hVa/3TQXjvPTiRXCnJPAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUuCZyGiCuLYE0aU7j5TFqY05kko0w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwNTM1OTAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBACjmqAp2Ci4sTHZci+qk
# tEAKsFk5HNVGKyWR2rFGXsd7cggZ04H5U4SV0fAL6fOE9dLvt4I7HBHLhpGdE5Uj
# Ly4NxLTG2bDAkeAVmxmd2uKWVGKym1aarDxXfv3GCN4mRX+Pn4c+py3S/6Kkt5eS
# DAIIsrzKw3Kh2SW1hCwXX/k1v4b+NH1Fjl+i/xPJspXCFuZB4aC5FLT5fgbRKqns
# WeAdn8DsrYQhT3QXLt6Nv3/dMzv7G/Cdpbdcoul8FYl+t3dmXM+SIClC3l2ae0wO
# lNrQ42yQEycuPU5OoqLT85jsZ7+4CaScfFINlO7l7Y7r/xauqHbSPQ1r3oIC+e71
# 5s2G3ClZa3y99aYx2lnXYe1srcrIx8NAXTViiypXVn9ZGmEkfNcfDiqGQwkml5z9
# nm3pWiBZ69adaBBbAFEjyJG4y0a76bel/4sDCVvaZzLM3TFbxVO9BQrjZRtbJZbk
# C3XArpLqZSfx53SuYdddxPX8pvcqFuEu8wcUeD05t9xNbJ4TtdAECJlEi0vvBxlm
# M5tzFXy2qZeqPMXHSQYqPgZ9jvScZ6NwznFD0+33kbzyhOSz/WuGbAu4cHZG8gKn
# lQVT4uA2Diex9DMs2WHiokNknYlLoUeWXW1QrJLpqO82TLyKTbBM/oZHAdIc0kzo
# STro9b3+vjn2809D0+SOOCVZMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGewwghnoAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAASFXpnsDlkvzdcAAAAABIUwDQYJYIZIAWUDBAIB
# BQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIE
# IF9JCl9de3YPpjKa1iM5Sas6g/4bk3DvBbNHpOGZH8vkMEIGCisGAQQBgjcCAQwx
# NDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20wDQYJKoZIhvcNAQEBBQAEggEATDy8vWdbVeqhS4tog7gaakNAB69DdoB7
# 30jnRDJtmnpzSsN3zV5AQqmd+/bk9zqCs2FbLaB9fc2THFE+JI0rWIDrfoizPWUZ
# ywVkcj3KNVqluUfdNmrxsQnzuyFG54BTvGjVOAF9kD9GScW5qMVyXE8enK/P+UuK
# T8t79uAsledp8xSn9xu3tm01VNhCZHMMlhR/D2SAf5NV27ltnWBdIAL0FlC54a+n
# iXkJfhQ0kLBf8y5ZQ6RMHVGGdELZqLoAEliS8KCfAtmXxpRjsigLZxKuPwfQNiI+
# 5IwfPrfNShK39MtF8hocrGkuW92UR/9IYt+lvXLu4DCH+14M9yEUoqGCF5QwgheQ
# BgorBgEEAYI3AwMBMYIXgDCCF3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJ
# YIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYB
# BAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCAreoIzkwxGcl63eNNZ3r/ds0tz8Wwj
# otoTmxqSyu6MLQIGaO/yH+1oGBMyMDI1MTAxNjIwMDcxMS43MTlaMASAAgH0oIHR
# pIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYD
# VQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hp
# ZWxkIFRTUyBFU046OTIwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WgghHqMIIHIDCCBQigAwIBAgITMwAAAgkIB+D5XIzm
# VQABAAACCTANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDAeFw0yNTAxMzAxOTQyNTVaFw0yNjA0MjIxOTQyNTVaMIHLMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQg
# QW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OTIw
# MC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZp
# Y2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDClEow9y4M3f1S9z1x
# tNEETwWL1vEiiw0oD7SXEdv4sdP0xsVyidv6I2rmEl8PYs9LcZjzsWOHI7dQkRL2
# 8GP3CXcvY0Zq6nWsHY2QamCZFLF2IlRH6BHx2RkN7ZRDKms7BOo4IGBRlCMkUv9N
# 9/twOzAkpWNsM3b/BQxcwhVgsQqtQ8NEPUuiR+GV5rdQHUT4pjihZTkJwraliz0Z
# bYpUTH5Oki3d3Bpx9qiPriB6hhNfGPjl0PIp23D579rpW6ZmPqPT8j12KX7ySZwN
# uxs3PYvF/w13GsRXkzIbIyLKEPzj9lzmmrF2wjvvUrx9AZw7GLSXk28Dn1XSf62h
# bkFuUGwPFLp3EbRqIVmBZ42wcz5mSIICy3Qs/hwhEYhUndnABgNpD5avALOV7sUf
# JrHDZXX6f9ggbjIA6j2nhSASIql8F5LsKBw0RPtDuy3j2CPxtTmZozbLK8TMtxDi
# MCgxTpfg5iYUvyhV4aqaDLwRBsoBRhO/+hwybKnYwXxKeeOrsOwQLnaOE5BmFJYW
# BOFz3d88LBK9QRBgdEH5CLVh7wkgMIeh96cH5+H0xEvmg6t7uztlXX2SV7xdUYPx
# A3vjjV3EkV7abSHD5HHQZTrd3FqsD/VOYACUVBPrxF+kUrZGXxYInZTprYMYEq6U
# IG1DT4pCVP9DcaCLGIOYEJ1g0wIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFEmL6NHE
# XTjlvfAvQM21dzMWk8rSMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1Gely
# MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNy
# bDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBD
# QSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYB
# BQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQBcXnxvODwk
# 4h/jbUBsnFlFtrSuBBZb7wSZfa5lKRMTNfNlmaAC4bd7Wo0I5hMxsEJUyupHwh4k
# D5qkRZczIc0jIABQQ1xDUBa+WTxrp/UAqC17ijFCePZKYVjNrHf/Bmjz7FaOI41k
# xueRhwLNIcQ2gmBqDR5W4TS2htRJYyZAs7jfJmbDtTcUOMhEl1OWlx/FnvcQbot5
# VPzaUwiT6Nie8l6PZjoQsuxiasuSAmxKIQdsHnJ5QokqwdyqXi1FZDtETVvbXfDs
# ofzTta4en2qf48hzEZwUvbkz5smt890nVAK7kz2crrzN3hpnfFuftp/rXLWTvxPQ
# cfWXiEuIUd2Gg7eR8QtyKtJDU8+PDwECkzoaJjbGCKqx9ESgFJzzrXNwhhX6Rc8g
# 2EU/+63mmqWeCF/kJOFg2eJw7au/abESgq3EazyD1VlL+HaX+MBHGzQmHtvOm3Ql
# 4wVTN3Wq8X8bCR68qiF5rFasm4RxF6zajZeSHC/qS5336/4aMDqsV6O86RlPPCYG
# JOPtf2MbKO7XJJeL/UQN0c3uix5RMTo66dbATxPUFEG5Ph4PHzGjUbEO7D35LuEB
# iiG8YrlMROkGl3fBQl9bWbgw9CIUQbwq5cTaExlfEpMdSoydJolUTQD5ELKGz1TJ
# ahTidd20wlwi5Bk36XImzsH4Ys15iXRfAjCCB3EwggVZoAMCAQICEzMAAAAVxedr
# ngKbSZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRp
# ZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4
# MzIyNVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qls
# TnXIyjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLA
# EBjoYH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrE
# qv1yaa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyF
# Vk3v3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1o
# O5pGve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg
# 3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2
# TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07B
# MzlMjgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJ
# NmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6
# r1AFemzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+
# auIurQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3
# FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl
# 0mWnG1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMA
# dQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAW
# gBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8v
# Y3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRf
# MjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEw
# LTA2LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL
# /Klv6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu
# 6WZnOlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5t
# ggz1bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfg
# QJY4rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8s
# CXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCr
# dTDFNLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZ
# c9d/HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2
# tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8C
# wYKiexcdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9
# JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDB
# cQZqELQdVTNYs6FwZvKhggNNMIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFt
# ZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjkyMDAt
# MDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNl
# oiMKAQEwBwYFKw4DAhoDFQB8762rPTQd7InDCQdb1kgFKQkCRKCBgzCBgKR+MHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7JvC
# AjAiGA8yMDI1MTAxNjE5MTIwMloYDzIwMjUxMDE3MTkxMjAyWjB0MDoGCisGAQQB
# hFkKBAExLDAqMAoCBQDsm8ICAgEAMAcCAQACAgj3MAcCAQACAhJTMAoCBQDsnROC
# AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSCh
# CjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAIpiuRoUAmxBIkiZNUbzipul
# dTvgf48z4q+mqJ08lUSdRvkyU1fhDpohn4pFEeryTpTsq9tTo+9YJdhl14fxcQP7
# EbgDWoan3a0QQu+dzNLihUlSZNzD8SEnqXvIfJy6jPnuhjgUFTDom1gGLQNh/UqO
# vkGFmieLDfnCyq3R85SlnfBk6Qq67pebPygnMAiTapEsw8T6llTvsSg8wD14GdC6
# HNSR50QpxR8jcr5GI+5LP3N7lgWlggKEz9voh2nlDqF1bFZKK/iv1ePLNvfhs2RN
# trzekfwx9ohMXwAGNyuspt4hTpOZu5H4n8F7RZW2RQZkMoCkdbYxyfsZzrqKAhox
# ggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAA
# AgkIB+D5XIzmVQABAAACCTANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkD
# MQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCCCo9gfVddnus8AzxKrp58L
# 0L7Fhf+8fAOAiyJZxcHHzTCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIGgb
# LB7IvfQCLmUOUZhjdUqK8bikfB6ZVVdoTjNwhRM+MIGYMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIJCAfg+VyM5lUAAQAAAgkwIgQgZacH
# z6qqYXdIKGB3Wrw1VIBnbQBffTPRnXkcNK+t/9cwDQYJKoZIhvcNAQELBQAEggIA
# I4yyb6r6VfV5mbQjyETyBwufKM0u8KDUO6NePbXfOBCoBUW02XsJs1P3A6maQoyX
# cOJAr3u+B+CxcXQaaVnfbbwgJwL20FmxtaSn01dP/22gSu9LkznNdtJDDr5AUU3C
# HxRTy/ok9lJbKylWOvsfapKSimezyzpvB78wAHolKG4XvONTrtsK6jmFLDJ4A9Mj
# 5839xvciYkYYpNZkvExXJlJweSBvwcCSt8febMOsOvXIWuUZZtfqw/Ib4dDCDHdC
# NUJzw/B1QUjEM7i8yPv4ZKcwrDZTsVEIFfIa5QHmXWdTcRqpVjL9Xym5JIb63uqt
# DM//N2bJQpthBkNQBj7E4zlE4WfK5wHqsURfK8nthbself3eiuNFEcrJyNRh+0YD
# v0gp6pDjCevt4K3l8yoGG8fLKbW10sNeLwX9RE49ulJCU+wIaWg9ktXSA2yZb2Zp
# 6bInw7v7aP01gT3YQxS9dBDDDSU7K1zoF2pgWi0sR6hpGJr6fmKXZ6cArSy4DErt
# uu3LL0fAF2h+buXeubiQPU2uOOoNKw40na7m1RLkIKeF9eqo+bzaT69OcA4/hiUe
# e9nLddT6m/Pw6a6zy+uXAfSc3plAkBNsIWgDPOvlZ7cUp5vQcT/iK2DeI5eJWBxN
# iylyTXLzuUSTeuoZvhfo6s4Df+nLSUl1kf8osJqjHQw=
# SIG # End signature block
