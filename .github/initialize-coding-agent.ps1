# SCRIPT ASSUMPTIONS
# This script makes the following critical assumptions that must be met for successful execution:
#
# 1. FOLDER STRUCTURE: App/ and TestApp/ folders exist relative to script location
#    - Script expects to find these folders in the current working directory
#    - Both folders must contain valid app.json files
#
# 2. RULESET FILES: nab.ruleset.json exists in BOTH App/ and TestApp/ folders
#    - Each app folder must have: {AppFolder}/.vscode/nab.ruleset.json
#    - Required paths: App/.vscode/nab.ruleset.json AND TestApp/.vscode/nab.ruleset.json
#
# 3. LINTERCOP NAMING: LinterCop releases follow naming convention: BusinessCentral.LinterCop.AL-{ALToolVersion}.dll
#    - GitHub releases at https://github.com/StefanMaron/BusinessCentral.LinterCop/releases/latest/download/
#
# 4. CODE COPS: PerTenantExtensionCop is used for app. LinterCop is used for app, if available for the AL Tools version.

[CmdletBinding()]
param(
    [switch]$SetupContainer,
    [string]$ContainerName = "bcserver"
)

$ErrorActionPreference = "Stop"

# This script is designed to run on Linux only
if (-not $IsLinux) {
    throw "This script is designed to run on Linux environments only (GitHub Codespaces/Actions). Current platform: $($PSVersionTable.Platform)"
}

$tempFolder = Join-Path $PWD.Path ".github/.tmp"
if (!(Test-Path -Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
}

$toolName = "Microsoft.Dynamics.BusinessCentral.Development.Tools.Linux"
$version = "17.0.28.6483-beta"

Write-Host "Install $toolName"
dotnet tool install $toolName --global --version $version

$ALToolVersion = (dotnet tool list $toolName --global | Select-String -Pattern "$toolName" | ForEach-Object { $_ -split '\s+' })[1]
Write-Host "Installed version $ALToolVersion of $toolName"

Install-Module -Name BcContainerHelper -Scope CurrentUser -Force -AllowClobber
Import-Module -Name BcContainerHelper -DisableNameChecking

$bcContainerHelperConfig.MicrosoftTelemetryConnectionString = ""

$analyzerFolderPath = Join-Path $env:HOME "/.dotnet/tools/.store/$($toolName.ToLower())/*/$($toolName.ToLower())/*/lib/*/*/" -Resolve

# Download BusinessCentral.LinterCop
$LinterCopDllPath = Join-Path $analyzerFolderPath "BusinessCentral.LinterCop.dll"
$LinterCopUrl = "https://github.com/StefanMaron/BusinessCentral.LinterCop/releases/latest/download/BusinessCentral.LinterCop.AL-$($ALToolVersion).dll"
$LinterCopAvailable = $false
try {
    Invoke-WebRequest -Uri $LinterCopUrl -OutFile $LinterCopDllPath -ErrorAction Stop
    Write-Host "Downloaded LinterCop DLL ($($LinterCopUrl)) to $LinterCopDllPath"
    $LinterCopAvailable = $true
}
catch {
    Write-Host "LINTERCOP DOWNLOAD ERROR:" -ForegroundColor Red
    Write-Host "Error Message: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Error Type: $($_.Exception.GetType().FullName)" -ForegroundColor Yellow
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Cyan
    if ($_.Exception.InnerException) {
        Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Yellow
    }
    Write-Host "Failed to download LinterCop DLL ($($LinterCopUrl)), ignoring until it is available for this version."
}


$projectFolder = $PWD.Path
$projectName = ""
if ($multiProject) {
    $projectName = Split-Path -Path $projectFolder -Leaf
    Write-Host "Processing project: $projectName"
}
$appFolder = Join-Path $projectFolder "App" -Resolve
$testAppFolder = Join-Path $projectFolder "TestApp"
$testAppExists = Test-Path -Path $testAppFolder -PathType Container
if ($testAppExists) {
    $testAppCacheFolder = Join-Path $testAppFolder '.alpackages'
    if (!(Test-Path -Path $testAppCacheFolder)) {
        New-Item -Path $testAppCacheFolder -ItemType Directory -Force | Out-Null
    }
}
$appFolders = @("App")
if ($testAppExists) {
    $appFolders += @("TestApp")
}

$appFolders | ForEach-Object {
    $currentAppFolder = Join-Path ($projectFolder) $_ -Resolve
    $ManifestObject = Get-Content (Join-Path $currentAppFolder "app.json") -Encoding UTF8 | ConvertFrom-Json
    $applicationVersion = $ManifestObject.Application
    $rulesetFile = Join-Path $currentAppFolder '.vscode\nab.ruleset.json' -Resolve

    $packagecachepath = Join-Path $currentAppFolder ".alpackages/"
    if (!(Test-Path -Path $packagecachepath)) {
        New-Item -Path $packagecachepath -ItemType Directory -Force | Out-Null
    }

    $AppFileName = (("{0}_{1}_{2}.app" -f $ManifestObject.publisher, $ManifestObject.name, $ManifestObject.version).Split([System.IO.Path]::GetInvalidFileNameChars()) -join '')
    $appPath = $(Join-Path $tempFolder $AppFileName)


    $ParametersList = @()
    $ParametersList += @(("/project:`"$currentAppFolder`" "))
    $ParametersList += @(("/packagecachepath:`"$packagecachepath`""))
    $ParametersList += @(("/out:`"{0}`"" -f "$appPath"))
    $ParametersList += @(("/loglevel:Warning"))

    $Analyzers = @("Microsoft.Dynamics.Nav.Analyzers.Common.dll", "Microsoft.Dynamics.Nav.CodeCop.dll", "Microsoft.Dynamics.Nav.UICop.dll")
    if ($_ -eq "App") {
        $Analyzers += @("Microsoft.Dynamics.Nav.PerTenantExtensionCop.dll")
        if ($LinterCopAvailable) {
            $Analyzers += @("BusinessCentral.LinterCop.dll")
        }
    }
    $Analyzers | ForEach-Object {
        $analyzerDllPath = Join-Path $analyzerFolderPath $_ -Resolve
        if (Test-Path -Path $analyzerDllPath) {
            $ParametersList += @(("/analyzer:`"$analyzerDllPath`""))
        }
        else {
            Write-Host "Analyzer not found: $analyzerDllPath"
        }
    }
    $ParametersList += @(("/ruleset:`"$rulesetFile`" "))
    switch ($_) {
        "App" {
            $compileScript = @"
al compile $($ParametersList -join " ")
"@
            if ($testAppExists) {
                $compileScript += @"

    Copy-Item -Path "$appPath" -Destination "$testAppCacheFolder"
"@
            }
            if ($testAppExists) {
                Get-ChildItem -Path $packagecachepath -Filter *.app | ForEach-Object {
                    Write-Host "Copy $($_.Name) to TestApp .alpackages"
                    Copy-Item -Path $_.FullName -Destination "$testAppCacheFolder"
                }
            }
        }
        "TestApp" {
            $compileScript = @"
al compile $($ParametersList -join " ")
"@
        }
        Default { throw "Unknown app type $_" }
    }
    $compileScriptPrefix = ""
    if ($projectName -ne "") {
        $compileScriptPrefix = "$projectName-"
    }
    $compileAppScriptPath = Join-Path $PWD.Path ".github/.tmp/$($compileScriptPrefix)compile-$($_.ToLower()).ps1"
    Set-Content -Path $compileAppScriptPath -Value $compileScript -Force
}

# Setup BC Container if requested
if ($SetupContainer.IsPresent) {
    Write-Host ""
    Write-Host "Setting up Business Central container..." -ForegroundColor Green

    $setupContainerScript = Join-Path $PSScriptRoot "setup-bc-container-linux.ps1"
    Write-Host "Using Linux-compatible container setup..." -ForegroundColor Yellow

    if (Test-Path $setupContainerScript) {
        try {
            & $setupContainerScript -containerName $ContainerName
        }
        catch {
            Write-Host "CONTAINER SETUP ERROR:" -ForegroundColor Red
            Write-Host "Error Message: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "Error Type: $($_.Exception.GetType().FullName)" -ForegroundColor Yellow
            Write-Host "Stack Trace:" -ForegroundColor Yellow
            Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Cyan
            if ($_.Exception.InnerException) {
                Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Yellow
            }
            Write-Host "Command that failed: & $setupContainerScript -containerName $ContainerName" -ForegroundColor Yellow
            Write-Warning "Container setup failed: $($_.Exception.Message)"
            Write-Host "Linux container setup failed. This may be due to Docker limitations in the current environment." -ForegroundColor Yellow
            Write-Host "Development environment is still configured for AL compilation." -ForegroundColor Green
            Write-Host "You can try running the container setup manually:" -ForegroundColor Yellow
            Write-Host "  .\setup-bc-container-linux.ps1 -skipContainer" -ForegroundColor Cyan
        }
    }
    else {
        Write-Warning "Container setup script not found: $setupContainerScript"
        Write-Host "You can manually run the container setup using:" -ForegroundColor Yellow
        Write-Host "  .\setup-bc-container-linux.ps1" -ForegroundColor Cyan
    }
}
else {
    Write-Host ""
    Write-Host "Container setup skipped (use -SetupContainer to enable)" -ForegroundColor Yellow
    Write-Host "Development environment configured for AL compilation only." -ForegroundColor Green
}

