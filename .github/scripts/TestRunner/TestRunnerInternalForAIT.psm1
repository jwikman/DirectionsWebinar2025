<#
    Function to initialize the test runner with the necessary parameters. The parameters are mainly used to open the connection to the client session. The parameters are saved as script variables for further use.
    This functions needs to be called before any other functions in this module.
#>
function Initialize-TestRunner(
    [ValidateSet("PROD", "OnPrem")]
    [string] $Environment,
    [ValidateSet("AAD", "Windows", "NavUserPassword")]
    [string] $AuthorizationType,
    [switch] $DisableSSLVerification,
    [pscredential] $Credential,
    [pscredential] $Token,
    [string] $EnvironmentName,
    [string] $ServiceUrl,
    [string] $ClientId,
    [string] $RedirectUri,
    [string] $AadTenantId,
    [string] $APIHost,
    [string] $ServerInstance,
    [Nullable[guid]] $CompanyId,
    [int] $ClientSessionTimeout = $script:DefaultClientSessionTimeout,
    [int] $TransactionTimeout = $script:DefaultTransactionTimeout.TotalMinutes,
    [string] $Culture = $script:DefaultCulture
) {
    Write-HostWithTimestamp "Initializing the AI Test Runner module..."

    $script:DisableSSLVerification = $DisableSSLVerification

    # Reset the script variables
    $script:Environment = ''
    $script:AuthorizationType = ''
    $script:EnvironmentName = ''
    $script:ClientId = ''
    $script:ServiceUrl = ''
    $script:APIHost = ''

    $script:CompanyId = $CompanyId
    

    # If -Environment is not specified then pick the default
    if ($Environment -eq '') {
        Write-Host "-Environment parameter is not provided. Defaulting to $script:DefaultEnvironment"

        $script:Environment = $script:DefaultEnvironment
    }
    else {
        $script:Environment = $Environment
    }

    # Depending on the Environment make sure necessary parameters are also specified
    switch ($script:Environment) {
        # PROD works only with AAD authorizatin type and OnPrem works on all 3 Authorization types
        'PROD' {
            if ($AuthorizationType -ne 'AAD') {
                throw "Only Authorization type 'AAD' can work in -Environment $Environment."
            }
            else {
                if ($AuthorizationType -eq '') {
                    Write-Host "-AuthorizationType parameter is not provided. Defaulting to $script:DefaultAuthorizationType"
                    $script:AuthorizationType = $script:DefaultAuthorizationType
                }
                else {
                    $script:AuthorizationType = $AuthorizationType
                }
            }

            if ($EnvironmentName -eq '') {
                Write-Host "-EnvironmentName parameter is not provided. Defaulting to $script:DefaultEnvironmentName"
                $script:EnvironmentName = $script:DefaultEnvironmentName
            }
            else {
                $script:EnvironmentName = $EnvironmentName
            }

            if ($ClientId -eq '') {
                Write-Error -Category InvalidArgument -Message 'ClientId is mandatory in the PROD environment'
            }
            else {
                $script:ClientId = $ClientId
            }
            if ($RedirectUri -eq '') {
                Write-Host "-RedirectUri parameter is not provided. Defaulting to $script:DefaultRedirectUri"
                $script:RedirectUri = $script:DefaultRedirectUri
            }
            else {
                $script:RedirectUri = $RedirectUri
            }
            if ($AadTenantId -eq '') {
                Write-Error -Category InvalidArgument -Message 'AadTenantId is mandatory in the PROD environment'
            }
            else {
                $script:AadTenantId = $AadTenantId
            }

            $script:AadTokenProvider = [AadTokenProvider]::new($script:AadTenantId, $script:ClientId, $script:RedirectUri)
            
            if (!$script:AadTokenProvider) {
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
            if ($Token -ne $null) {
                $tenantDomain = ($Token.UserName.Substring($Token.UserName.IndexOf('@') + 1))
            }
            else {
                $tenantDomain = ($Credential.UserName.Substring($Credential.UserName.IndexOf('@') + 1))
            }
            $script:discoveryUrl = "https://businesscentral.dynamics.com/$tenantDomain/$EnvironmentName/deployment/url"

            if ($ServiceUrl -eq '') {
                $script:ServiceUrl = Get-SaaSServiceURL
                Write-Host "ServiceUrl is not provided. Defaulting to $script:ServiceUrl"
            }
            else {
                $script:ServiceUrl = $ServiceUrl
            }

            if ($APIHost -eq '') {
                $script:APIHost = $script:DefaultSaaSAPIHost + '/' + $script:EnvironmentName
                Write-Host "APIHost is not provided. Defaulting to $script:APIHost"
            }
            else {
                $script:APIHost = $APIHost
            }
        }
        'OnPrem' {
            if ($AuthorizationType -eq '') {
                Write-Host "-AuthorizationType parameter is not provided. Defaulting to $script:DefaultAuthorizationType"
                $script:AuthorizationType = $script:DefaultAuthorizationType
            }
            else {
                $script:AuthorizationType = $AuthorizationType
            }

            # OnPrem, -ServiceUrl should be provided else default is selected. On other environments, the Service Urls are built
            if ($ServiceUrl -eq '') {
                Write-Host "Valid ServiceUrl is not provided. Defaulting to $script:DefaultServiceUrl"
                $script:ServiceUrl = $script:DefaultServiceUrl
            }
            else {
                $script:ServiceUrl = $ServiceUrl
            }

            if ($ServerInstance -eq '') {
                Write-Host "ServerInstance is not provided. Defaulting to $script:DefaultServerInstance"
                $script:ServerInstance = $script:DefaultServerInstance
            }
            else {
                $script:ServerInstance = $ServerInstance
            }

            if ($APIHost -eq '') {
                $script:APIHost = $script:DefaultOnPremAPIHost + '/' + "Navision_" + $script:ServerInstance
                Write-Host "APIHost is not provided. Defaulting to $script:APIHost"
            }
            else {
                $script:APIHost = $APIHost
            }
            
            $script:Tenant = GetTenantFromServiceUrl -Uri $script:ServiceUrl
        }
    }

    switch ($script:AuthorizationType) {
        # -Credential or -Token should be specified if authorization type is AAD.
        "AAD" {
            if ($null -eq $Credential -and $Token -eq $null) {
                throw "Parameter -Credential or -Token should be defined when selecting 'AAD' authorization type."
            }
            if ($null -ne $Credential -and $Token -ne $null) {
                throw "Specify only one parameter -Credential or -Token when selecting 'AAD' authorization type."
            }
        }
        # -Credential should be specified if authorization type is NavUserPassword.
        "NavUserPassword" {
            if ($null -eq $Credential) {
                throw "Parameter -Credential should be defined when selecting 'NavUserPassword' authorization type."
            }
        }
        "Windows" {
            if ($null -ne $Credential) {
                throw "Parameter -Credential should not be defined when selecting 'Windows' authorization type."
            }
        }
    }
    
    $script:Credential = $Credential
    $script:ClientSessionTimeout = $ClientSessionTimeout
    $script:TransactionTimeout = [timespan]::FromMinutes($TransactionTimeout);
    $script:Culture = $Culture;

    Test-AITestToolkitConnection
}

function GetTenantFromServiceUrl([Uri]$Uri)
{
    # Extract the query string part of the URI
    $queryString = [Uri]$Uri -replace '.*\?', ''
    $params = @{}
    
    $queryString -split '&' | ForEach-Object {  
        if ($_ -match '([^=]+)=(.*)') { 
            $params[$matches[1]] = $matches[2] 
        }  
    }

    if($params['tenant'])
    {
        return $params['tenant']
    } 
    
    return 'default'    
}

# Test the connection to the AI Test Toolkit
function Test-AITestToolkitConnection {
    try {
        Write-HostWithTimestamp "Testing the connection to the AI Test Toolkit..."

        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$script:DisableSSLVerification -AuthorizationType $script:AuthorizationType -Credential $script:Credential -ServiceUrl $script:ServiceUrl -ClientSessionTimeout $script:ClientSessionTimeout -TransactionTimeout $script:TransactionTimeout -Culture $script:Culture
        
        Write-HostWithTimestamp "Opening the Test Form $script:TestRunnerPage"
        $form = Open-TestForm -TestPage $script:TestRunnerPage -DisableSSLVerification:$script:DisableSSLVerification -AuthorizationType $script:AuthorizationType -ClientContext $clientContext

        # There will be an exception if the form is not opened
        Write-HostWithTimestamp "Successfully opened the Test Form $script:TestRunnerPage" -ForegroundColor Green

        $clientContext.CloseForm($form)

        # Check API connection
        $APIEndpoint = Get-DefaultAPIEndpointForAITLogEntries

        Write-HostWithTimestamp "Testing the connection to the AI Test Toolkit Log Entries API: $APIEndpoint"
        Invoke-BCRestMethod -Uri $APIEndpoint
        Write-HostWithTimestamp "Successfully connected to the AI Test Toolkit Log Entries API" -ForegroundColor Green

        $APIEndpoint = Get-DefaultAPIEndpointForAITTestMethodLines

        Write-HostWithTimestamp "Testing the connection to the AI Test Toolkit Test Method Lines API: $APIEndpoint"
        Invoke-BCRestMethod -Uri $APIEndpoint
        Write-HostWithTimestamp "Successfully connected to the AI Test Toolkit Test Method Lines API" -ForegroundColor Green
    }
    catch {
        $scriptArgs = @{
            AuthorizationType    = $script:AuthorizationType
            ServiceUrl           = $script:ServiceUrl
            APIHost              = $script:APIHost
            ClientSessionTimeout = $script:ClientSessionTimeout
            TransactionTimeout   = $script:TransactionTimeout
            Culture              = $script:Culture
            TestRunnerPage       = $script:TestRunnerPage
            APIEndpoint          = $script:APIEndpoint
        }
        Write-HostWithTimestamp "Exception occurred. Script arguments: $($scriptArgs | Out-String)"
        throw $_.Exception.Message
    }
    finally {
        if ($clientContext) {
            $clientContext.Dispose()
        }
    }     
}

# Reset the test suite pending tests
function Reset-AITTestSuite {
    param (
        [Parameter(Mandatory = $true)]
        [string] $SuiteCode,
        [int] $ClientSessionTimeout = $script:ClientSessionTimeout,
        [timespan] $TransactionTimeout = $script:TransactionTimeout
    )

    try {
        Write-HostWithTimestamp "Opening test runner page: $script:TestRunnerPage"

        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$script:DisableSSLVerification -AuthorizationType $script:AuthorizationType -Credential $script:Credential -ServiceUrl $script:ServiceUrl -ClientSessionTimeout $ClientSessionTimeout -TransactionTimeout $TransactionTimeout -Culture $script:Culture

        $form = Open-TestForm -TestPage $script:TestRunnerPage -DisableSSLVerification:$script:DisableSSLVerification -AuthorizationType $script:AuthorizationType -ClientContext $clientContext        

        $SelectSuiteControl = $clientContext.GetControlByName($form, "AIT Suite Code")        
        $clientContext.SaveValue($SelectSuiteControl, $SuiteCode);        

        Write-HostWithTimestamp "Resetting the test suite $SuiteCode"

        $ResetAction = $clientContext.GetActionByName($form, "ResetTestSuite")
        $clientContext.InvokeAction($ResetAction)
    }
    finally {
        if ($clientContext) {
            $clientContext.Dispose()
        }
    }
}

# Invoke the AI Test Suite
function Invoke-AITSuite
(
    [Parameter(Mandatory = $true)]
    [string] $SuiteCode,
    [string] $SuiteLineNo,
    [int] $ClientSessionTimeout = $script:ClientSessionTimeout,
    [timespan] $TransactionTimeout = $script:TransactionTimeout
) {
    $NoOfPendingTests = 0
    $TestResult = @()
    do {
        try {
            Write-HostWithTimestamp "Opening test runner page: $script:TestRunnerPage"

            $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$script:DisableSSLVerification -AuthorizationType $script:AuthorizationType -Credential $script:Credential -ServiceUrl $script:ServiceUrl -ClientSessionTimeout $ClientSessionTimeout -TransactionTimeout $TransactionTimeout -Culture $script:Culture

            $form = Open-TestForm -TestPage $script:TestRunnerPage -DisableSSLVerification:$script:DisableSSLVerification -AuthorizationType $script:AuthorizationType -ClientContext $clientContext            

            $SelectSuiteControl = $clientContext.GetControlByName($form, "AIT Suite Code")            
            $clientContext.SaveValue($SelectSuiteControl, $SuiteCode);            

            if ($SuiteLineNo -ne '') {
                $SelectSuiteLineControl = $clientContext.GetControlByName($form, "Line No. Filter")
                $clientContext.SaveValue($SelectSuiteLineControl, $SuiteLineNo);
            }

            Invoke-NextTest -SuiteCode $SuiteCode -ClientContext $clientContext -Form $form

            # Get the results for the last run
            $TestResult += Get-AITSuiteTestResultInternal -SuiteCode $SuiteCode -TestRunVersion 0 | ConvertFrom-Json            

            $NoOfPendingTests = $clientContext.GetControlByName($form, "No. of Pending Tests")            
            $NoOfPendingTests = [int] $NoOfPendingTests.StringValue            
        }
        catch {
            $stackTraceText = $_.Exception.StackTrace + "Script stack trace: " + $_.ScriptStackTrace 
            $testResultError = @(
                @{
                    aitCode        = $SuiteCode
                    status         = "Error"
                    message        = $_.Exception.Message
                    errorCallStack = $stackTraceText
                    endTime        = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")
                }
            )
            $TestResult += $testResultError
        }
        finally {
            if ($clientContext) {
                $clientContext.Dispose()
            }
        }
    }
    until ($NoOfPendingTests -eq 0)
    return $TestResult
}

# Run the next test in the suite
function Invoke-NextTest {
    param (
        [Parameter(Mandatory = $true)]
        [string] $SuiteCode,
        [string] $SuiteLineNo,
        [Parameter(Mandatory = $true)]
        [ClientContext] $clientContext,
        [Parameter(Mandatory = $true)]
        [ClientLogicalForm] $form
    )
    $NoOfPendingTests = [int] $clientContext.GetControlByName($form, "No. of Pending Tests").StringValue

    if ($NoOfPendingTests -gt 0) {
        $StartNextAction = $clientContext.GetActionByName($form, "RunNextTest")

        $message = "Starting the next test in the suite $SuiteCode, Number of pending tests: $NoOfPendingTests"
        if ($SuiteLineNo -ne '') {
            $message += ", Filtering the suite line number: $SuiteLineNo"
        }
        Write-HostWithTimestamp $message

        $clientContext.InvokeAction($StartNextAction)
    }
    else {
        throw "There are no tests to run. Try resetting the test suite. Number of pending tests: $NoOfPendingTests"
    }

    $NewNoOfPendingTests = [int] $clientContext.GetControlByName($form, "No. of Pending Tests").StringValue
    if ($NewNoOfPendingTests -eq $NoOfPendingTests) {
        throw "There was an error running the test. Number of pending tests: $NewNoOfPendingTests"
    }
}

# Get Suite Test Result for specified version
# If version is not provided then get the latest version
function Get-AITSuiteTestResultInternal {
    param (
        [Parameter(Mandatory = $true)]
        [string] $SuiteCode,
        [Int32] $TestRunVersion,
        [Int32] $CodeunitId,
        [string] $CodeunitName,
        [string] $TestStatus,
        [string] $ProcedureName
    )

    if ($TestRunVersion -lt 0) {
        throw "TestRunVersion should be 0 or greater"
    }
    
    $APIEndpoint = Get-DefaultAPIEndpointForAITLogEntries

    # if AIT suite version is not provided then get the latest version
    if ($TestRunVersion -eq 0) {
        # Odata to sort by version and get all the entries with highest version
        $APIQuery = Build-LogEntryAPIFilter -SuiteCode $SuiteCode -TestRunVersion $TestRunVersion -CodeunitId $CodeunitId -CodeunitName $CodeunitName -TestStatus $TestStatus -ProcedureName $ProcedureName
        $AITVersionAPI = $APIEndpoint + $APIQuery + "&`$orderby=version desc&`$top=1&`$select=version"
        
        Write-HostWithTimestamp "Getting the latest version of the AIT Suite from $AITVersionAPI"
        $AITApiResponse = Invoke-BCRestMethod -Uri $AITVersionAPI
        
        $TestRunVersion = $AITApiResponse.value[0].version
    }

    $APIQuery = Build-LogEntryAPIFilter -SuiteCode $SuiteCode -TestRunVersion $TestRunVersion -CodeunitId $CodeunitId -CodeunitName $CodeunitName -TestStatus $TestStatus -ProcedureName $ProcedureName
    $AITLogEntryAPI = $APIEndpoint + $APIQuery

    Write-HostWithTimestamp "Getting the AIT Suite Test Results from $AITLogEntryAPI"
    $AITLogEntries = Invoke-BCRestMethod -Uri $AITLogEntryAPI

    # Convert the response to JSON
    
    $AITLogEntriesJson = $AITLogEntries.value | ConvertTo-Json -Depth 100 -AsArray
    return $AITLogEntriesJson
}


# Get Suite Test Result for specified version
# If version is not provided then get the latest version
function Get-AITSuiteEvaluationResultInternal {
    param (
        [Parameter(Mandatory = $true)]
        [string] $SuiteCode,
        [Int32] $SuiteLineNo,
        [Int32] $TestRunVersion,
        [string] $TestState
    )

    if ($TestRunVersion -lt 0) {
        throw "TestRunVersion should be 0 or greater"
    }
    
    $APIEndpoint = Get-DefaultAPIEndpointForAITEvaluationLogEntries

    Write-Host "Getting the AIT Suite Evaluation Results for Suite Code: $SuiteCode, Suite Line No: $SuiteLineNo, Test Run Version: $TestRunVersion, Test State: $TestState"

    # if AIT suite version is not provided then get the latest version
    if ($TestRunVersion -eq 0) {
        # Odata to sort by version and get all the entries with highest version
        $APIQuery = Build-LogEvaluationEntryAPIFilter -SuiteCode $SuiteCode -TestRunVersion $TestRunVersion -SuiteLineNo $SuiteLineNo -TestState $TestState
        $AITVersionAPI = $APIEndpoint + $APIQuery + "&`$orderby=version desc&`$top=1&`$select=version"
        
        Write-HostWithTimestamp "Getting the latest version of the AIT Suite from $AITVersionAPI"
        $AITApiResponse = Invoke-BCRestMethod -Uri $AITVersionAPI
        
        $TestRunVersion = $AITApiResponse.value[0].version
    }

    $APIQuery = Build-LogEvaluationEntryAPIFilter -SuiteCode $SuiteCode -TestRunVersion $TestRunVersion -SuiteLineNo $SuiteLineNo -TestState $TestState
    $AITEvaluationLogEntryAPI = $APIEndpoint + $APIQuery

    Write-HostWithTimestamp "Getting the AIT Suite Evaluation Results from $AITEvaluationLogEntryAPI"
    $AITEvaluationLogEntries = Invoke-BCRestMethod -Uri $AITEvaluationLogEntryAPI

    # Convert the response to JSON
    $AITEvaluationLogEntriesJson = $AITEvaluationLogEntries.value | ConvertTo-Json -Depth 100 -AsArray
    return $AITEvaluationLogEntriesJson
}

# Get Test Method Lines for a Suite
function Get-AITSuiteTestMethodLinesInternal {
    param (
        [Parameter(Mandatory = $true)]
        [string] $SuiteCode,
        [Int32] $TestRunVersion,
        [Int32] $CodeunitId,
        [string] $CodeunitName,
        [string] $TestStatus,
        [string] $ProcedureName
    )

    if ($TestRunVersion -lt 0) {
        throw "TestRunVersion should be 0 or greater"
    }
    
    $APIEndpoint = Get-DefaultAPIEndpointForAITTestMethodLines

    $APIQuery = Build-TestMethodLineAPIFilter -SuiteCode $SuiteCode -TestRunVersion $TestRunVersion -CodeunitId $CodeunitId -CodeunitName $CodeunitName -TestStatus $TestStatus
    $AITTestMethodLinesAPI = $APIEndpoint + $APIQuery

    Write-HostWithTimestamp "Getting the Test Method Lines from $AITTestMethodLinesAPI"
    $AITTestMethodLines = Invoke-BCRestMethod -Uri $AITTestMethodLinesAPI

    # Convert the response to JSON
    $AITTestMethodLinesJson = $AITTestMethodLines.value | ConvertTo-Json
    return $AITTestMethodLinesJson
}

function Get-DefaultAPIEndpointForAITLogEntries {
    $CompanyPath = ''
    if ($script:CompanyId -ne [guid]::Empty -and $null -ne $script:CompanyId) {
        $CompanyPath = '/companies(' + $script:CompanyId + ')'
    }
    
    $TenantParam = ''
    if($script:Tenant)
    {
        $TenantParam = "tenant=$script:Tenant&"
    }
    $APIEndpoint = "$script:APIHost/api/microsoft/aiTestToolkit/v2.0$CompanyPath/aitTestLogEntries?$TenantParam"
    Write-Host "APIEndpoint: $APIEndpoint"

    return $APIEndpoint
}

function Get-DefaultAPIEndpointForAITTestMethodLines {
    $CompanyPath = ''
    if ($script:CompanyId -ne [guid]::Empty -and $null -ne $script:CompanyId) {
        $CompanyPath = '/companies(' + $script:CompanyId + ')'
    }

    $TenantParam = ''
    if($script:Tenant)
    {
        $TenantParam = "tenant=$script:Tenant&"
    }

    $APIEndpoint = "$script:APIHost/api/microsoft/aiTestToolkit/v2.0$CompanyPath/aitTestMethodLines?$TenantParam"

    return $APIEndpoint
}

function Get-DefaultAPIEndpointForAITEvaluationLogEntries {
    $CompanyPath = ''
    if ($script:CompanyId -ne [guid]::Empty -and $null -ne $script:CompanyId) {
        $CompanyPath = '/companies(' + $script:CompanyId + ')'
    }
    
    $TenantParam = ''
    if($script:Tenant)
    {
        $TenantParam = "tenant=$script:Tenant&"
    }
    $APIEndpoint = "$script:APIHost/api/microsoft/aiTestToolkit/v2.0$CompanyPath/aitEvaluationLogEntries?$TenantParam"
    Write-Host "APIEndpoint: $APIEndpoint"

    return $APIEndpoint
}

function Build-LogEntryAPIFilter() {
    param (
        [Parameter(Mandatory = $true)]
        [string] $SuiteCode,
        [Int32] $TestRunVersion,
        [Int32] $CodeunitId,
        [string] $CodeunitName,
        [string] $TestStatus,
        [string] $ProcedureName
    )

    $filter = "`$filter=aitCode eq '" + $SuiteCode + "'"
    if ($TestRunVersion -ne 0) {
        $filter += " and version eq " + $TestRunVersion
    }
    if ($CodeunitId -ne 0) {
        $filter += " and codeunitId eq " + $CodeunitId
    }
    if ($CodeunitName -ne '') {
        $filter += " and codeunitName eq '" + $CodeunitName + "'"
    }
    if ($TestStatus -ne '') {
        $filter += " and status eq '" + $TestStatus + "'"
    }
    if ($ProcedureName -ne '') {
        $filter += " and procedureName eq '" + $ProcedureName + "'"
    }

    return $filter
}

function Build-TestMethodLineAPIFilter() {
    param (
        [Parameter(Mandatory = $true)]
        [string] $SuiteCode,
        [Int32] $TestRunVersion,
        [Int32] $CodeunitId,
        [string] $CodeunitName,
        [string] $TestStatus,
        [string] $ProcedureName
    )

    $filter = "`$filter=aitCode eq '" + $SuiteCode + "'"
    if ($TestRunVersion -ne 0) {
        $filter += " and version eq " + $TestRunVersion
    }
    if ($CodeunitId -ne 0) {
        $filter += " and codeunitId eq " + $CodeunitId
    }
    if ($CodeunitName -ne '') {
        $filter += " and codeunitName eq '" + $CodeunitName + "'"
    }
    if ($TestStatus -ne '') {
        $filter += " and status eq '" + $TestStatus + "'"
    }

    return $filter
}

function Build-LogEvaluationEntryAPIFilter() {
    param (
        [Parameter(Mandatory = $true)]
        [string] $SuiteCode,
        [Int32] $SuiteLineNo,
        [Int32] $TestRunVersion,
        [string] $TestState
    )

    $filter = "`$filter=aitCode eq '" + $SuiteCode + "'"
    if ($TestRunVersion -ne 0) {
        $filter += " and version eq " + $TestRunVersion
    }
    if ($SuiteLineNo -ne 0) {
        $filter += " and aitTestMethodLineNo eq " + $SuiteLineNo
    }
    if ($TestState -ne '') {
        $filter += " and state eq '" + $TestState + "'"
    }

    return $filter
}

# Upload the input dataset needed to run the AI Test Suite
function Set-InputDatasetInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string] $InputDatasetFilename,
        [Parameter(Mandatory = $true)]
        [string] $InputDataset,
        [int] $ClientSessionTimeout = $script:ClientSessionTimeout,
        [timespan] $TransactionTimeout = $script:TransactionTimeout
    )
    try {
        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$script:DisableSSLVerification -AuthorizationType $script:AuthorizationType -Credential $script:Credential -ServiceUrl $script:ServiceUrl -ClientSessionTimeout $ClientSessionTimeout -TransactionTimeout $TransactionTimeout -Culture $script:Culture

        $form = Open-TestForm -TestPage $script:TestRunnerPage -DisableSSLVerification:$script:DisableSSLVerification -AuthorizationType $script:AuthorizationType -ClientContext $clientContext

        $SelectSuiteControl = $clientContext.GetControlByName($form, "Input Dataset Filename")
        $clientContext.SaveValue($SelectSuiteControl, $InputDatasetFilename);
        
        Write-HostWithTimestamp "Uploading the Input Dataset $InputDatasetFilename"

        $SelectSuiteControl = $clientContext.GetControlByName($form, "Input Dataset")
        $clientContext.SaveValue($SelectSuiteControl, $InputDataset);

        $validationResultsError = Get-FormError($form)
        if ($validationResultsError.Count -gt 0) {
            Write-HostWithTimestamp "There is an error uploading the Input Dataset: $InputDatasetFilename" -ForegroundColor Red
            Write-HostWithTimestamp $validationResultsError -ForegroundColor Red
        }

        $clientContext.CloseForm($form)
    }
    finally {
        if ($clientContext) {
            $clientContext.Dispose()
        }
    }     
}

#Upload the XML test suite definition needed to setup the AI Test Suite
function  Set-SuiteDefinitionInternal {
    param (
        [Parameter(Mandatory = $true)]
        [xml] $SuiteDefinition,
        [int] $ClientSessionTimeout = $script:ClientSessionTimeout,
        [timespan] $TransactionTimeout = $script:TransactionTimeout
    )
    try {
        $clientContext = Open-ClientSessionWithWait -DisableSSLVerification:$script:DisableSSLVerification -AuthorizationType $script:AuthorizationType -Credential $script:Credential -ServiceUrl $script:ServiceUrl -ClientSessionTimeout $ClientSessionTimeout -TransactionTimeout $TransactionTimeout -Culture $script:Culture

        $form = Open-TestForm -TestPage $script:TestRunnerPage -DisableSSLVerification:$script:DisableSSLVerification -AuthorizationType $script:AuthorizationType -ClientContext $clientContext

        Write-HostWithTimestamp "Uploading the Suite Definition"
        $SelectSuiteControl = $clientContext.GetControlByName($form, "Suite Definition")
        $clientContext.SaveValue($SelectSuiteControl, $SuiteDefinition.OuterXml);
        
        # Check if the suite definition is set correctly
        $validationResultsError = Get-FormError($form)
        if ($validationResultsError.Count -gt 0) {
            throw $validationResultsError
        }
        $clientContext.CloseForm($form)
    }
    catch {
        Write-HostWithTimestamp "`There is an error uploading the Suite Definition. Please check the Suite Definition XML:`n $($SuiteDefinition.OuterXml)" -ForegroundColor Red
        if ($validationResultsError.Count -gt 0) {
            throw $_.Exception.Message
        }
        else {
            throw $_.Exception
        }
    }
    finally {
        if ($clientContext) {
            $clientContext.Dispose()
        }
    }
}

function Get-FormError {
    param (
        [ClientLogicalForm]
        $form
    )
    if ($form.HasValidatonResults -eq $true) {
        $validationResults = $form.ValidationResults
        $validationResultsError = @()
        foreach ($validationResult in $validationResults | Where-Object { $_.Severity -eq "Error" }) {
            $validationResultsError += "TestPage: $script:TestRunnerPage, Status: Error, Message: $($validationResult.Description), ErrorCallStack: $(Get-PSCallStack)"
        }
        return ($validationResultsError -join "`n")
    }  
}

function Invoke-BCRestMethod {
    param (
        [string]$Uri
    )
    switch ($script:AuthorizationType) {
        "Windows" {
            Invoke-RestMethod -Uri $Uri -Method Get -ContentType "application/json" -UseDefaultCredentials -AllowUnencryptedAuthentication
        }
        "NavUserPassword" {
            Invoke-RestMethod -Uri $Uri -Method Get -ContentType "application/json" -Credential $script:Credential -AllowUnencryptedAuthentication
        }
        "AAD" {
            $script:AadTokenProvider
            if ($null -ne $script:AadTokenProvider) {
                throw "You need to specify the AadTokenProvider for obtaining the token if using AAD authentication"
            }

            $token = $AadTokenProvider.GetToken($Credential)
            $headers = @{
                Authorization = "Bearer $token"
                Accept        = "application/json"
            }
            return Invoke-RestMethod -Uri $Uri -Method Get -Headers $headers
        }
        default {
            Write-Error "Invalid authentication type specified. Use 'Windows', 'UserPassword', or 'AAD'."
        }
    }
}

function Write-HostWithTimestamp {
    param (
        [string] $Message
    )
    Write-Host "[$($script:Tenant) $(Get-Date)] $Message"
}

$script:DefaultEnvironment = "OnPrem"
$script:DefaultAuthorizationType = 'Windows'
$script:DefaultEnvironmentName = "sandbox"
$script:DefaultServiceUrl = 'http://localhost:48900'
$script:DefaultRedirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
$script:DefaultOnPremAPIHost = "http://localhost:7047"
$script:DefaultSaaSAPIHost = "https://api.businesscentral.dynamics.com/v2.0"
$script:DefaultServerInstance = "NAV"
$script:DefaultClientSessionTimeout = 60;
$script:DefaultTransactionTimeout = [timespan]::FromMinutes(60);
$script:DefaultCulture = "en-US";

$script:TestRunnerPage = '149042'
$script:ClientAssembly1 = "Microsoft.Dynamics.Framework.UI.Client.dll"
$script:ClientAssembly2 = "NewtonSoft.Json.dll"
$script:ClientAssembly3 = "Microsoft.Internal.AntiSSRF.dll"

if (!$script:TypesLoaded) {
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

$ErrorActionPreference = "Stop"
$script:AadTokenProvider = $null
$script:Credential = $null

Export-ModuleMember -Function Initialize-TestRunner, Reset-AITTestSuite, Invoke-AITSuite, Set-InputDatasetInternal, Set-SuiteDefinitionInternal, Get-AITSuiteTestResultInternal, Get-AITSuiteEvaluationResultInternal, Get-AITSuiteTestMethodLinesInternal

# SIG # Begin signature block
# MIIoKAYJKoZIhvcNAQcCoIIoGTCCKBUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAOki8D+wwfFmip
# Q/ssbvA4EpjFU9+rxgFJDzmjf36uiKCCDXYwggX0MIID3KADAgECAhMzAAAEhV6Z
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGggwghoEAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAASFXpnsDlkvzdcAAAAABIUwDQYJYIZIAWUDBAIB
# BQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIE
# IKvAt9Lw5MXiUeCXGLOOKYNdOSkdSM8v2EDaOw+7FRLBMEIGCisGAQQBgjcCAQwx
# NDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20wDQYJKoZIhvcNAQEBBQAEggEArpDnzXZZOHjAjGiCN90wC6ZKyCj3DfU0
# 4CoY7Xhf5WmkDAaCVAoYJtJV7+ELHigl0tBL5SflVdly6NkXRTK/GqDK0+0HITyf
# 6VKrbVtRARuL4KKqPS/0HwLmVChjYJK3/+/ZeDAVXFjqWiG8agpLAIgVRDxWtvMQ
# 7mzNkuPWDEMFuAENd9VH4vtn1590HoLnwXD3rzc1IORIBK5ZldtIZCKbRQ/FeQpN
# yE/0LrxYgMKkKUhshwaNmUtMf/ffMF7VJBA0ROAgO424GRWEjs1gxCN3NSQ0OhvH
# yGMqtKuRY/Ln3fK61QSJFaD/7fzO6V4tcgk9aDPtznfOz7lIS9I9z6GCF7Awghes
# BgorBgEEAYI3AwMBMYIXnDCCF5gGCSqGSIb3DQEHAqCCF4kwgheFAgEDMQ8wDQYJ
# YIZIAWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIBQQIBAQYKKwYB
# BAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCAqBvUoMLWekPGHpKklmKaQ43EWdBI5
# tps4Oinf/9/TpgIGaN7wO5eDGBMyMDI1MTAxNTIwNTEzNy42NTVaMASAAgH0oIHZ
# pIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYD
# VQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNV
# BAsTHm5TaGllbGQgVFNTIEVTTjo0QzFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEf4wggcoMIIFEKADAgECAhMzAAAC
# GCXZkgXi5+XkAAEAAAIYMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMB4XDTI1MDgxNDE4NDgyNVoXDTI2MTExMzE4NDgyNVowgdMx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOjRDMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKC
# AgEAsdzo6uuQJqAfxLnvEBfIvj6knK+p6bnMXEFZ/QjPOFywlcjDfzI8Dg1nzDlx
# m7/pqbvjWhyvazKmFyO6qbPwClfRnI57h5OCixgpOOCGJJQIZSTiMgui3B8DPiFt
# JPcfzRt3FsnxjLXwBIjGgnjGfmQl7zejA1WoYL/qBmQhw/FDFTWebxfo4m0RCCOx
# f2qwj31aOjc2aYUePtLMXHsXKPFH0tp5SKIF/9tJxRSg0NYEvQqVilje8aQkPd3q
# zAux2Mc5HMSK4NMTtVVCYAWDUZ4p+6iDI9t5BNCBIsf5ooFNUWtxCqnpFYiLYkHf
# FfxhVUBZ8LGGxYsA36snD65s2Hf4t86k0e8WelH/usfhYqOM3z2yaI8rg08631Ik
# wqUzyQoEPqMsHgBem1xpmOGSIUnVvTsAv+lmECL2RqrcOZlZax8K0aiij8h6UkWB
# N2IA/ikackTSGVRBQmWWZuLFWV/T4xuNzscC0X7xo4fetgpsqaEA0jY/QevkTvLv
# 4OlNN9eOL8LNh7Vm0R65P7oabOQDqtUFAwCgjgPJ0iV/jQCaMAcO3SYpG5wSAYiJ
# kk4XLjNSlNxU2Idjs1sORhl7s7LC6hOb7bVAHVwON74GxfFNiEIA6BfudANjpQJ0
# nUc/ppEXpT4pgDBHsYtV8OyKSjKsIxOdFR7fIJIjDc8DvUkCAwEAAaOCAUkwggFF
# MB0GA1UdDgQWBBQkLqHEXDobY7dHuoQCBa4sX7aL0TAfBgNVHSMEGDAWgBSfpxVd
# AF5iXYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIw
# UENBJTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYG
# A1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0B
# AQsFAAOCAgEAnkjRhjwPgdoIpvt4YioT/j0LWuBxF3ARBKXDENggraKvC0oRPwbj
# AmsXnPEmtuo5MD8uJ9Xw9eYrxqqkK4DF9snZMrHMfooxCa++1irLz8YoozC4tci+
# a4N37Sbke1pt1xs9qZtvkPgZGWn5BcwVfmAwSZLHi2CuZ06Y0/X+t6fNBnrbMVov
# NaDX4WPdyI9GEzxfIggDsck2Ipo4VXL/Arcz7p2F7bEZGRuyxjgMC+woCkDJaH/y
# k/wcZpAsixe4POdN0DW6Zb35O3Dg3+a6prANMc3WIdvfKDl75P0aqcQbQAR7b0f4
# gH4NMkUct0Wm4GN5KhsE1YK7V/wAqDKmK4jx3zLz3a8Hsxa9HB3GyitlmC5sDhOl
# 4QTGN5kRi6oCoV4hK+kIFgnkWjHhSRNomz36QnbCSG/BHLEm2GRU9u3/I4zUd9E1
# AC97IJEGfwb+0NWb3QEcrkypdGdWwl0LEObhrQR9B1V7+edcyNmsX0p2BX0rFpd1
# PkXJSbxf8IcEiw/bkNgagZE+VlDtxXeruLdo5k3lGOv7rPYuOEaoZYxDvZtpHP9P
# 36wmW4INjR6NInn2UM+krP/xeLnRbDBkm9RslnoDhVraliKDH62BxhcgL9tiRgOH
# lcI0wqvVWLdv8yW8rxkawOlhCRqT3EKECW8ktUAPwNbBULkT+oWcvBcwggdxMIIF
# WaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNy
# b3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAx
# ODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAy
# MDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL
# 1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5K
# Wv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTeg
# Cjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv62
# 6GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SH
# JMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss25
# 4o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/Nme
# Rd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afo
# mXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLi
# Mxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb
# 0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W2
# 9R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQF
# AgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1Ud
# DgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdM
# g30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJ
# KwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQF
# MAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8w
# TTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVj
# dHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBK
# BggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9N
# aWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1V
# ffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1
# OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce57
# 32pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihV
# J9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZ
# UnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW
# 9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k
# +SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pF
# EUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L
# +DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1
# ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6
# CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDWTCCAkECAQEwggEBoYHZ
# pIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYD
# VQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNV
# BAsTHm5TaGllbGQgVFNTIEVTTjo0QzFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUAnWtGrXWi
# uNE8QrKfm4CtGr57z+mggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDANBgkqhkiG9w0BAQsFAAIFAOyZ6WEwIhgPMjAyNTEwMTUwOTM1MjlaGA8y
# MDI1MTAxNjA5MzUyOVowdzA9BgorBgEEAYRZCgQBMS8wLTAKAgUA7JnpYQIBADAK
# AgEAAgIRowIB/zAHAgEAAgIT+jAKAgUA7Js64QIBADA2BgorBgEEAYRZCgQCMSgw
# JjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3
# DQEBCwUAA4IBAQAHCjV/FL2RGylELyqDIBDYiraBFImUYcW+YEZ/N3rrmituZvl5
# zW69K9OjmJDplbAe/yvh3B1UeCj0F2zWtdWh8gNJYDzVXc3KQQkq4hzjFjogfnma
# Mk5NQ1+YEWCBSQbAvBfBS8cwiN22IjRoazME/Syo5tMQDNxtlb/OO+/LprZb/tIX
# 4tdIyXMfum5D46Nq6tsM0vZhKLNNWI8+1KR3Kc9hUxIV33oUrMEALZIVOqFDPsFF
# g4aP8FCyrjuYXrTEPBTtI9AlUeo5eW1lYQGJ7OlYFW6OtYvgCOl0U9hN/UZaY2Eb
# wgMYAI+78TD78g9ZlkbxzD9XUM7cm8nd4SojMYIEDTCCBAkCAQEwgZMwfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIYJdmSBeLn5eQAAQAAAhgwDQYJ
# YIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkq
# hkiG9w0BCQQxIgQgLdvnDJ9/9zq9pSufLQuIn/xNCsYvA/OjVwvqiO81NqUwgfoG
# CyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCCZE9yJuOTItIwWaES6lzGKK1XcSoz1
# ynRzaOVzx9eFajCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# AhMzAAACGCXZkgXi5+XkAAEAAAIYMCIEIAi0MtXXU7BQt7M8gaNpjPO9fNJqm0Qf
# UcNtFHLSTLqCMA0GCSqGSIb3DQEBCwUABIICABDStfvy2b5IbcWzE5D+lH1JGFug
# ptL9w+DykcOemRDH2ID4NHgcVE/2eRaE0teZ/SzzAQVVwCffhoxjOkPosobeZNMs
# NqbJyAxSp9VMuoIwukJWyInRtaWnZy0F9XBhN7snCR3Z4ZRsGpDaTXr0mwo/+vp9
# Ek3srKE3hMl3UXbIPQQi1hfjssyHtMM0Qy8WH/0LQ/h8w4qoQOpM6XpSZwYdmSDv
# bwPGp5vOkOAp9eHJMxfC0cBJebESZQcKGNQhRnTJsQgfLfUZiKBfoZFSZVKxzU86
# uHpY8r5RifZKjYgZyAGNgli/TlmlPRBO4F9JgT+yWUFjjubH91KBQqrqQWF9AViw
# laZylEUuvQendqWyybJKCQ6NqYUQCD12mltzD+14ikREiPNmuiAAIqPuSpQDL0CL
# r+JMi/Q2tzrzHu2kXXo+8SUBZNBKecUH0Bl9tJawhFI/3bCn+BernSh+O5KbultI
# Kgc6jfbcdVLUeM4bEIgz5ugtpuBd6KdlJJ4Y1coRI3FG+z3w3OBcZ+HVaEV3uwj5
# Syfz2GFo1yabnrc12zG+w7GnZGXZv+qTqPHCZGuJsDNltd0/U7Mow/i7GU2z7q/q
# /2VpZChoun/ZtV8cHgivV1pmFf/Ovl0v+USPnTc4J/DSHnNMddWD+UgpgtTezJ7F
# V4WDEuXtMjtG7qDs
# SIG # End signature block
