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
    [switch]$SetupContainer = $false,
    [string]$ContainerName = "bcserver"
)

$ErrorActionPreference = "Stop"

$tempFolder = Join-Path $PWD.Path ".github/.tmp"
if (!(Test-Path -Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
}
$version = $null
if ($IsLinux) {
    $toolName = "Microsoft.Dynamics.BusinessCentral.Development.Tools.Linux"
    $version = "17.0.28.6483-beta"
}
else {
    $toolName = "Microsoft.Dynamics.BusinessCentral.Development.Tools"
}
Write-Host "Install $toolName"
if ($version) {
    dotnet tool install $toolName --global --version $version
}
else {
    dotnet tool install $toolName --global --prerelease
}
$ALToolVersion = (dotnet tool list $toolName --global | Select-String -Pattern "$toolName" | ForEach-Object { $_ -split '\s+' })[1]
Write-Host "Installed version $ALToolVersion of $toolName"

Install-Module -Name BcContainerHelper -Scope CurrentUser -Force -AllowClobber
Import-Module -Name BcContainerHelper -DisableNameChecking

$bcContainerHelperConfig.MicrosoftTelemetryConnectionString = ""
$bcContainerHelperConfig.TrustedNuGetFeeds = @(
    [PSCustomObject]@{
        "Url"      = "https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/MSApps/nuget/v3/index.json";
        "Patterns" = @("*")
    },
    [PSCustomObject]@{
        "Url"      = "https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/MSSymbols/nuget/v3/index.json";
        "Patterns" = @("*")
    },
    [PSCustomObject]@{
        "Url"      = "https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/AppSourceSymbols/nuget/v3/index.json"
        "Patterns" = @("*")
    }
)

if ($IsLinux) {
    $analyzerFolderPath = Join-Path $env:HOME "/.dotnet/tools/.store/$($toolName.ToLower())/*/$($toolName.ToLower())/*/lib/*/*/" -Resolve
}
else {
    # Used for development on Windows
    $analyzerFolderPath = Join-Path $env:USERPROFILE "/.dotnet/tools/.store/$($toolName.ToLower())/*/$($toolName.ToLower())/*/lib/*/*/" -Resolve
}

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
$AppManifestObject = Get-Content (Join-Path $appFolder "app.json") -Encoding UTF8 | ConvertFrom-Json
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

    $nonMsftDependencies = $ManifestObject.dependencies | Where-Object { $_.publisher -ne "Microsoft" -and $_.name -ne $AppManifestObject.name }
    foreach ($Dependency in $nonMsftDependencies) {
        $DependencyFileName = (("{0}_{1}_{2}.app" -f $Dependency.publisher, $Dependency.name, $Dependency.version).Split([System.IO.Path]::GetInvalidFileNameChars()) -join '')
        if (!(Test-Path -Path (Join-Path $packagecachepath $DependencyFileName))) {
            $PackageName = ("{0}.{1}.symbols.{2}" -f $Dependency.publisher, $Dependency.name, $Dependency.id ) -replace ' ', ''
            Write-Host "Get $PackageName"

            Download-BcNuGetPackageToFolder -packageName $PackageName -downloadDependencies none -folder $packagecachepath -version $Dependency.version -select Exact -allowPrerelease
        }
        else {
            Write-Host "$DependencyFileName already in .alpackages"
        }
    }

    $msftDependencies = $ManifestObject.dependencies | Where-Object { $_.publisher -eq "Microsoft" }
    foreach ($Dependency in $msftDependencies) {
        $DependencyFileName = (("{0}_{1}_*.app" -f $Dependency.publisher, $Dependency.name).Split([System.IO.Path]::GetInvalidFileNameChars()) -join '')
        if (!(Test-Path -Path (Join-Path $packagecachepath $DependencyFileName))) {
            $PackageName = ("{0}.{1}.symbols.{2}" -f $Dependency.publisher, $Dependency.name, $Dependency.id ) -replace ' ', ''
            Write-Host "Get $PackageName"

            Download-BcNuGetPackageToFolder -packageName $PackageName -downloadDependencies none -folder $packagecachepath -version $Dependency.version -select LatestMatching
        }
        else {
            Write-Host "$DependencyFileName already in .alpackages"
        }
    }
    if (!(Test-Path -Path (Join-Path $packagecachepath "Microsoft_Application_*.app"))) {
        Write-Host "Get symbols for Application $applicationVersion"
        $PackageName = "Microsoft.Application.symbols"
        Download-BcNuGetPackageToFolder -packageName $PackageName -downloadDependencies all -folder $packagecachepath -version $applicationVersion -select LatestMatching
    }
    else {
        Write-Host "Symbols for Application already in .alpackages"
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
if ($SetupContainer) {
    Write-Host ""
    Write-Host "Setting up Business Central container..." -ForegroundColor Green
    $setupContainerScript = Join-Path $PSScriptRoot "setup-bc-container.ps1"
    
    if (Test-Path $setupContainerScript) {
        & $setupContainerScript -containerName $ContainerName
    } else {
        Write-Warning "Container setup script not found: $setupContainerScript"
        Write-Host "You can manually run the container setup using:" -ForegroundColor Yellow
        Write-Host "  .\setup-bc-container.ps1" -ForegroundColor Cyan
    }
}

