function Setup-Enviroment
(
    [ValidateSet("PROD","OnPrem")]
    [string] $Environment = $script:DefaultEnvironment,
    [string] $SandboxName = $script:DefaultSandboxName,
    [pscredential] $Credential,
    [pscredential] $Token,
    [string] $ClientId,
    [string] $RedirectUri,
    [string] $AadTenantId
)
{
    switch ($Environment)
    {
        "PROD" 
        {           
            $authority = "https://login.microsoftonline.com/"
            $resource = "https://api.businesscentral.dynamics.com"
            $global:AadTokenProvider = [AadTokenProvider]::new($AadTenantId, $ClientId, $RedirectUri)
            
            if(!$global:AadTokenProvider){
                $example = @'

    $UserName = 'USERNAME'
    $Password = 'PASSWORD'
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $UserCredential = New-Object System.Management.Automation.PSCredential($UserName, $securePassword)

    $script:AADTenantID = 'Guid like - 212415e1-054e-401b-ad32-3cdfa301b1d2'
    $script:ClientId = 'Guid like 0a576aea-5e61-4153-8639-4c5fd5e7d1f6'
    $script:RedirectUri = 'https://login.microsoftonline.com/common/oauth2/nativeclient'
    $global:AadTokenProvider = [AadTokenProvider]::new($script:AADTenantID, $script:ClientId, $scrit:RedirectUri)
'@
                throw 'You need to initialize and set the $global:AadTokenProvider. Example: ' + $example
            }
            $tenantDomain = ''
            if ($Token -ne $null)
            {
                $tenantDomain = ($Token.UserName.Substring($Token.UserName.IndexOf('@') + 1))
            }
            else
            {
                $tenantDomain = ($Credential.UserName.Substring($Credential.UserName.IndexOf('@') + 1))
            }
            $script:discoveryUrl = "https://businesscentral.dynamics.com/$tenantDomain/$SandboxName/deployment/url" #Sandbox
            $script:automationApiBaseUrl = "https://api.businesscentral.dynamics.com/v1.0/api/microsoft/automation/v1.0/companies"
        }
    }
}

function Get-SaaSServiceURL()
{
     $status = ''

     $provisioningTimeout = new-timespan -Minutes 15
     $stopWatch = [diagnostics.stopwatch]::StartNew()
     while ($stopWatch.elapsed -lt $provisioningTimeout)
     {
        $response = Invoke-RestMethod -Method Get -Uri $script:discoveryUrl
        if($response.status -eq 'Ready')
        {
            $clusterUrl = $response.data
            return $clusterUrl
        }
        else
        {
            Write-Host "Could not get Service url status - $($response.status)"
        }

        sleep -Seconds 10
     }
}

function Run-BCPTTestsInternal
(
    [ValidateSet("PROD","OnPrem")]
    [string] $Environment,
    [ValidateSet('Windows','NavUserPassword','AAD')]
    [string] $AuthorizationType,
    [pscredential] $Credential,
    [pscredential] $Token,
    [string] $SandboxName,
    [int] $TestRunnerPage,
    [switch] $DisableSSLVerification,
    [string] $ServiceUrl,
    [string] $SuiteCode,
    [int] $SessionTimeoutInMins,
    [string] $ClientId,
    [string] $RedirectUri,
    [string] $AadTenantId,
    [switch] $SingleRun
)
{
    <#
        .SYNOPSIS
        Runs the Application Beanchmark Tool(BCPT) tests.

        .DESCRIPTION
        Runs BCPT tests in different environment.

        .PARAMETER Environment
        Specifies the environment the tests will be run in. The supported values are 'PROD', 'TIE' and 'OnPrem'. Default is 'PROD'.

        .PARAMETER AuthorizationType
        Specifies the authorizatin type needed to authorize to the service. The supported values are 'Windows','NavUserPassword' and 'AAD'.

        .PARAMETER Credential
        Specifies the credential object that needs to be used to authenticate. Both 'NavUserPassword' and 'AAD' needs a valid credential objects to eb passed in.
        
        .PARAMETER Token
        Specifies the AAD token credential object that needs to be used to authenticate. The credential object should contain username and token.

        .PARAMETER SandboxName
        Specifies the sandbox name. This is necessary only when the environment is either 'PROD' or 'TIE'. Default is 'sandbox'.
        
        .PARAMETER TestRunnerPage
        Specifies the page id that is used to start the tests. Defualt is 150010.
        
        .PARAMETER DisableSSLVerification
        Specifies if the SSL verification should be disabled or not.
        
        .PARAMETER ServiceUrl
        Specifies the base url of the service. This parameter is used only in 'OnPrem' environment.
        
        .PARAMETER SuiteCode
        Specifies the code that will be used to select the test suite to be run.
        
        .PARAMETER SessionTimeoutInMins
        Specifies the timeout for the client session. This will be same the length you expect the test suite to run.

        .PARAMETER ClientId
        Specifies the guid that the BC is registered with in AAD.

        .PARAMETER SingleRun
        Specifies if it is a full run or a single iteration run.

        .INPUTS
        None. You cannot pipe objects to Add-Extension.

        .EXAMPLE
        C:\PS> Run-BCPTTestsInternal -DisableSSLVerification -Environment OnPrem -AuthorizationType Windows -ServiceUrl 'htto://localhost:48900' -TestRunnerPage 150002 -SuiteCode DEMO -SessionTimeoutInMins 20
        File.txt

        .EXAMPLE
        C:\PS> Run-BCPTTestsInternal -DisableSSLVerification -Environment PROD -AuthorizationType AAD -Credential $Credential -TestRunnerPage 150002 -SuiteCode DEMO -SessionTimeoutInMins 20 -ClientId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    #>

    Run-NextTest -DisableSSLVerification -Environment $Environment -AuthorizationType $AuthorizationType -Credential $Credential -Token $Token -SandboxName $SandboxName -ServiceUrl $ServiceUrl -TestRunnerPage $TestRunnerPage -SuiteCode $SuiteCode -SessionTimeout $SessionTimeoutInMins -ClientId $ClientId -RedirectUri $RedirectUri -AadTenantId $AadTenantId -SingleRun:$SingleRun
}

function Run-NextTest
(
    [switch] $DisableSSLVerification,
    [ValidateSet("PROD","OnPrem")]
    [string] $Environment,
    [ValidateSet('Windows','NavUserPassword','AAD')]
    [string] $AuthorizationType,
    [pscredential] $Credential,
    [pscredential] $Token,
    [string] $SandboxName,
    [string] $ServiceUrl,
    [int] $TestRunnerPage,
    [string] $SuiteCode,
    [int] $SessionTimeout,
    [string] $ClientId,
    [string] $RedirectUri,
    [string] $AadTenantId,
    [switch] $SingleRun
)
{
    Setup-Enviroment -Environment $Environment -SandboxName $SandboxName -Credential $Credential -Token $Token -ClientId $ClientId -RedirectUri $RedirectUri -AadTenantId $AadTenantId
    if ($Environment -ne 'OnPrem')
    {
        $ServiceUrl = Get-SaaSServiceURL
    }
    
    try
    {
        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AuthorizationType -Credential $Credential -ServiceUrl $ServiceUrl -ClientSessionTimeout $SessionTimeout
        $form = Open-TestForm -TestPage $TestRunnerPage -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AuthorizationType -ClientContext $clientContext

        $SelectSuiteControl = $clientContext.GetControlByName($form, "Select Code")
        $clientContext.SaveValue($SelectSuiteControl, $SuiteCode);

        if ($SingleRun.IsPresent)
        {
            $StartNextAction = $clientContext.GetActionByName($form, "StartNextPRT")
        }
        else
        {
            $StartNextAction = $clientContext.GetActionByName($form, "StartNext")
        }

        $clientContext.InvokeAction($StartNextAction)
        
        $clientContext.CloseForm($form)
    }
    finally
    {
        if($clientContext)
        {
            $clientContext.Dispose()
        }
    } 
}

function Get-NoOfIterations
(
    [ValidateSet("PROD","OnPrem")]
    [string] $Environment,
    [ValidateSet('Windows','NavUserPassword','AAD')]
    [string] $AuthorizationType,
    [pscredential] $Credential,
    [pscredential] $Token,
    [string] $SandboxName,
    [int] $TestRunnerPage,
    [switch] $DisableSSLVerification,
    [string] $ServiceUrl,
    [string] $SuiteCode,
    [String] $ClientId,
    [string] $RedirectUri,
    [string] $AadTenantId
)
{
    <#
        .SYNOPSIS
        Opens the Application Beanchmark Tool(BCPT) test runner page and reads the number of sessions that needs to be created.

        .DESCRIPTION
        Opens the Application Beanchmark Tool(BCPT) test runner page and reads the number of sessions that needs to be created.

        .PARAMETER Environment
        Specifies the environment the tests will be run in. The supported values are 'PROD', 'TIE' and 'OnPrem'.

        .PARAMETER AuthorizationType
        Specifies the authorizatin type needed to authorize to the service. The supported values are 'Windows','NavUserPassword' and 'AAD'.

        .PARAMETER Credential
        Specifies the credential object that needs to be used to authenticate. Both 'NavUserPassword' and 'AAD' needs a valid credential objects to eb passed in.
        
        .PARAMETER Token
        Specifies the AAD token credential object that needs to be used to authenticate. The credential object should contain username and token.

        .PARAMETER SandboxName
        Specifies the sandbox name. This is necessary only when the environment is either 'PROD' or 'TIE'. Default is 'sandbox'.
        
        .PARAMETER TestRunnerPage
        Specifies the page id that is used to start the tests.
        
        .PARAMETER DisableSSLVerification
        Specifies if the SSL verification should be disabled or not.
        
        .PARAMETER ServiceUrl
        Specifies the base url of the service. This parameter is used only in 'OnPrem' environment.
        
        .PARAMETER SuiteCode
        Specifies the code that will be used to select the test suite to be run.
        
        .PARAMETER ClientId
        Specifies the guid that the BC is registered with in AAD.

        .INPUTS
        None. You cannot pipe objects to Add-Extension.

        .EXAMPLE
        C:\PS> $NoOfTasks,$TaskLifeInMins,$NoOfTests = Get-NoOfIterations -DisableSSLVerification -Environment OnPrem -AuthorizationType Windows -ServiceUrl 'htto://localhost:48900' -TestRunnerPage 150010 -SuiteCode DEMO
        File.txt

        .EXAMPLE
        C:\PS> $NoOfTasks,$TaskLifeInMins,$NoOfTests = Get-NoOfIterations -DisableSSLVerification -Environment PROD -AuthorizationType AAD -Credential $Credential -TestRunnerPage 50010 -SuiteCode DEMO -ClientId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

    #>

    Setup-Enviroment -Environment $Environment -SandboxName $SandboxName -Credential $Credential -Token $Token -ClientId $ClientId -RedirectUri $RedirectUri -AadTenantId $AadTenantId
    if ($Environment -ne 'OnPrem')
    {
        $ServiceUrl = Get-SaaSServiceURL
    }
    
    try
    {
        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AuthorizationType -Credential $Credential -ServiceUrl $ServiceUrl
        $form = Open-TestForm -TestPage $TestRunnerPage -DisableSSLVerification:$DisableSSLVerification -AuthorizationType $AuthorizationType -ClientContext $clientContext
        $SelectSuiteControl = $clientContext.GetControlByName($form, "Select Code")
        $clientContext.SaveValue($SelectSuiteControl, $SuiteCode);

        $testResultControl = $clientContext.GetControlByName($form, "No. of Instances")
        $NoOfInstances = [int]$testResultControl.StringValue

        $testResultControl = $clientContext.GetControlByName($form, "Duration (minutes)")
        $DurationInMins = [int]$testResultControl.StringValue

        $testResultControl = $clientContext.GetControlByName($form, "No. of Tests")
        $NoOfTests = [int]$testResultControl.StringValue
        
        $clientContext.CloseForm($form)
        return $NoOfInstances,$DurationInMins,$NoOfTests
    }
    finally
    {
        if($clientContext)
        {
            $clientContext.Dispose()
        }
    } 
}

$ErrorActionPreference = "Stop"

if(!$script:TypesLoaded)
{
    Add-type -Path "$PSScriptRoot\Microsoft.Dynamics.Framework.UI.Client.dll"
    Add-type -Path "$PSScriptRoot\NewtonSoft.Json.dll"
    Add-type -Path "$PSScriptRoot\Microsoft.Internal.AntiSSRF.dll"
    
    $alTestRunnerInternalPath = Join-Path $PSScriptRoot "ALTestRunnerInternal.psm1"
    Import-Module "$alTestRunnerInternalPath"

    $clientContextScriptPath = Join-Path $PSScriptRoot "ClientContext.ps1"
    . "$clientContextScriptPath"
    
    $aadTokenProviderScriptPath = Join-Path $PSScriptRoot "AadTokenProvider.ps1"
    . "$aadTokenProviderScriptPath"
}

$script:TypesLoaded = $true;
$script:ActiveDirectoryDllsLoaded = $false;
$script:AadTokenProvider = $null

$script:DefaultEnvironment = "OnPrem"
$script:DefaultAuthorizationType = 'Windows'
$script:DefaultSandboxName = "sandbox"
$script:DefaultTestPage = 150002;
$script:DefaultTestSuite = 'DEFAULT'
$script:DefaultErrorActionPreference = 'Stop'

$script:DefaultTcpKeepActive = [timespan]::FromMinutes(2);
$script:DefaultTransactionTimeout = [timespan]::FromMinutes(30);
$script:DefaultCulture = "en-US";

Export-ModuleMember -Function Run-BCPTTestsInternal,Get-NoOfIterations

# SIG # Begin signature block
# MIIoDwYJKoZIhvcNAQcCoIIoADCCJ/wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCicbavk73W/qRx
# 9RJOvG5ONWB+skuaJLtfeHAwO0ANgaCCDXYwggX0MIID3KADAgECAhMzAAAEhV6Z
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGe8wghnrAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAASFXpnsDlkvzdcAAAAABIUwDQYJYIZIAWUDBAIB
# BQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIE
# IPhVCTF5ZLZGumMFldiC/Wo+Dwas40zHnYANRc74wYQJMEIGCisGAQQBgjcCAQwx
# NDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20wDQYJKoZIhvcNAQEBBQAEggEANVwFqwBEvVjvAt0QjOAKhPBABmJ1p9Dx
# zlN+YITWC0iIZqBI4RGYAlUXlQ/KiWbNIDF5AmnG752cVKZHOjwKmJt9kMMlH1sm
# 6DuvG9ZbLan6QZ4+YzV6MiQO7XG0YYk0e7v3EwEKggWI1mFL9aWPvNswulknBcac
# raCWyA60Udn4utvcJvs/hcoCIE6HazWkLYDN26xt7DTkjt4yN9JNakq5f9ku54sb
# ZJrE52IDekLPUqtgd8aefLgA3j7QtD4his5ehobMZ4TuHSx/sSkQzG0W/OkcMmbI
# t+CJUuNEZ9qFx/E9dawvWbJdd0GtoI8hw5v4W0QVb+027esv/3A1sqGCF5cwgheT
# BgorBgEEAYI3AwMBMYIXgzCCF38GCSqGSIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJ
# YIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYB
# BAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCAvBhtxnLHMdIc33hrNBso8BcQxsFAN
# PAfAopuUIpzdpgIGaMLaDKaTGBMyMDI1MTAxMzE3MTE0OS40NDFaMASAAgH0oIHR
# pIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYD
# VQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hp
# ZWxkIFRTUyBFU046OTIwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WgghHtMIIHIDCCBQigAwIBAgITMwAAAgkIB+D5XIzm
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
# cQZqELQdVTNYs6FwZvKhggNQMIICOAIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFt
# ZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjkyMDAt
# MDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNl
# oiMKAQEwBwYFKw4DAhoDFQB8762rPTQd7InDCQdb1kgFKQkCRKCBgzCBgKR+MHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7JeD
# fzAiGA8yMDI1MTAxMzEzNTYxNVoYDzIwMjUxMDE0MTM1NjE1WjB3MD0GCisGAQQB
# hFkKBAExLzAtMAoCBQDsl4N/AgEAMAoCAQACAg+TAgH/MAcCAQACAhHLMAoCBQDs
# mNT/AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBABSxGyFFBnA/q5RMy5vU
# XpmhSUWnft4hF/DM3z4O5pdpyd8iVEfZg3qR2f613FtvEZ6JxnAoFtOi/BdHlOvh
# z0bA8ZD7IjRH9kWHTomm6nUqOIoyZ7pG47r6Wn2/WIehFE7TthBCBvmofYLKBsCf
# R2Aa3wvceSfejqCnhglN/0xoOHm8lqnLZHDUDUbWKuH0+VVe4Amh4tRprVVSv4H7
# 0+ukqNBCpjAHWlBgQ5cLK4q8LuwJ4hiNycks461OFzZTHM+DbljuWaRsZfV9sjKh
# qOM7MDWxTjoGHQ1COP3ZZ7FxYbH8j0qf6lJO5fuyRQD64FXdeoGEWJJ6THQRth1Z
# aWoxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAAgkIB+D5XIzmVQABAAACCTANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcN
# AQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBkkUiDL8P/JAxCWQgU
# ODHBl5Lg24DXRtYih3EvOy7iZTCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0E
# IGgbLB7IvfQCLmUOUZhjdUqK8bikfB6ZVVdoTjNwhRM+MIGYMIGApH4wfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIJCAfg+VyM5lUAAQAAAgkwIgQg
# vXEL2/JTJRFzPqUS4Gw91LKTDy8QAnmLyele0VPteP0wDQYJKoZIhvcNAQELBQAE
# ggIAWsKSwy9r1QgwsuYmy7HYo3loju8BbgCTIn8e0/446+LnDMEExcr7MXgS3T7c
# AxkJ77qS24LSLUrTvhR6D5tPFrMHaVOnFVgwsoGIbvENh77aeLJ6hcOnRZVFNyMb
# 8+7TGmwn2f+MSyt5yVmpCIebw0S4FUH2ba7GTBWDvIw5fatq/EIkFyscw6stU6kh
# k/HhUtUWhJ0I9CrBR8cWaUMkpwQfvWf2MLzQeZNMOrcoNciBwspm0y05nqOynUsx
# gFWN92daG8DsYts+nKDQ0qqrH8bAQzkgdUAIWwZTanbg33NKF0MJQKsvpFT1W4vV
# x4eco0llkIDFgugOKy6JR0v/9TOPLnI7CvCbBAZ+vyKDDXDZn9t2aC27Q6aXJhvL
# nUAvZ0O2s2TXz8wsy+kQs2/r5Yq/x3N9bvJTvH+f2Jr6d/1453VCV/upRlNOFn3O
# E9zbjKkieVACpX7uKA2PG0j80m9OlkZJpI48goFccOGomj43UPhlGKk6EbAM8MVG
# WneSrQmMfVHrim7e3ZM8AMDS7tCG2DIsi1i6hiZfyC7CFDpFZyFTLow84tMMMyZ4
# paAGXAZ30SxsSKzvaZTXJrHZpivDBOZmq0clVEfx42I2QvLtQpAoZ8BoMKWf+KMv
# 4SEMrSzong0o3C5dvFHzeq4DEospjSnsB54lJEkySF9v4DM=
# SIG # End signature block
