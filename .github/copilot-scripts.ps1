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
# 4. CODE COPS: LinterCop is used for app, if available for the AL Tools version.
#
# 5. NVRAPPDEVOPS: Uses NVRAppDevOps module with Paket CLI for faster NuGet package downloads
#    - See https://blog.kine.cz/posts/paketforbc/ for more information

$ErrorActionPreference = "Stop"

$tempFolder = Join-Path $PWD.Path ".github/.tmp"
if (!(Test-Path -Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
}

if ($IsLinux) {
    $toolName = "Microsoft.Dynamics.BusinessCentral.Development.Tools.Linux"
}
else {
    $toolName = "Microsoft.Dynamics.BusinessCentral.Development.Tools"
}
Write-Host "Install $toolName"
dotnet tool install $toolName --global --prerelease
$ALToolVersion = (dotnet tool list $toolName --global | Select-String -Pattern "$toolName" | ForEach-Object { $_ -split '\s+' })[1]
Write-Host "Installed version $ALToolVersion of $toolName"

Install-Module -Name BcContainerHelper -Scope CurrentUser -Force -AllowClobber
Import-Module -Name BcContainerHelper -DisableNameChecking

# Ensure 'Sort' alias exists for NVRAppDevOps compatibility (especially on Linux)
if (-not (Get-Alias -Name Sort -ErrorAction SilentlyContinue)) {
    Set-Alias -Name Sort -Value Sort-Object -Scope Global
}

Install-Module -Name NVRAppDevOps -Scope CurrentUser -Force -AllowClobber
Import-Module -Name NVRAppDevOps -DisableNameChecking

# # Install Paket as a .NET tool (works on both Windows and Linux)
# Write-Host "Installing Paket as .NET tool..."
# dotnet tool install paket --global --version 8.1.3 2>&1 | Out-Null
# if ($LASTEXITCODE -ne 0) {
#     Write-Host "Paket already installed, updating..."
#     dotnet tool update paket --global 2>&1 | Out-Null
# }

# Create a wrapper script for paket.exe that NVRAppDevOps expects
$paketFolder = Join-Path $tempFolder "paket"
if (!(Test-Path -Path $paketFolder)) {
    New-Item -Path $paketFolder -ItemType Directory -Force | Out-Null
}

$paketExe = Join-Path $paketFolder "paket.exe"

# Create a wrapper script that calls the .NET tool
if ($IsLinux) {
    # On Linux, create a bash wrapper
    $wrapperContent = @"
#!/bin/bash
exec paket `$@
"@
    Set-Content -Path $paketExe -Value $wrapperContent -NoNewline
    chmod +x $paketExe
} else {
    # On Windows, create a cmd wrapper
    $wrapperContent = @"
@echo off
paket %*
"@
    Set-Content -Path $paketExe -Value $wrapperContent -NoNewline
}

Write-Host "Paket CLI path: $paketFolder"

# Define NuGet sources for Paket
$nugetSources = @(
    "https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/MSApps/nuget/v3/index.json",
    "https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/MSSymbols/nuget/v3/index.json",
    "https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/AppSourceSymbols/nuget/v3/index.json"
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

    # For TestApp, copy the main app first and create a modified app.json without it in dependencies
    $skipPaket = $false
    if ($_ -eq "TestApp") {
        # Copy the main app to TestApp's .alpackages
        $mainAppFile = Get-ChildItem -Path $appFolder -Filter "*.app" | Select-Object -First 1
        if ($mainAppFile) {
            Write-Host "Copying main app $($mainAppFile.Name) to TestApp .alpackages"
            Copy-Item -Path $mainAppFile.FullName -Destination $packagecachepath -Force

            # Create a temporary app.json without the main app dependency
            $tempAppJson = Join-Path $currentAppFolder "app.json.paket"
            $modifiedManifest = $ManifestObject | ConvertTo-Json -Depth 10
            $modifiedManifestObj = $modifiedManifest | ConvertFrom-Json
            $modifiedManifestObj.dependencies = @($ManifestObject.dependencies | Where-Object { $_.name -ne $AppManifestObject.name })
            $modifiedManifestObj | ConvertTo-Json -Depth 10 | Set-Content -Path $tempAppJson -Encoding UTF8

            # Temporarily rename app.json
            $originalAppJson = Join-Path $currentAppFolder "app.json"
            $backupAppJson = Join-Path $currentAppFolder "app.json.backup"
            Move-Item -Path $originalAppJson -Destination $backupAppJson -Force
            Move-Item -Path $tempAppJson -Destination $originalAppJson -Force
        }
        else {
            Write-Host "Warning: Main app not found, skipping Paket for TestApp"
            $skipPaket = $true
        }
    }

    # Use Paket CLI via NVRAppDevOps to download dependencies
    if (-not $skipPaket) {
        Write-Host "Downloading dependencies for $_ using Paket CLI..."
        Push-Location $currentAppFolder
        try {
            # Invoke-PaketForAL will:
            # 1. Read app.json and create paket.dependencies file
            # 2. Resolve dependency tree
            # 3. Download all dependencies (including transitive) to 'Packages' folder
            # 4. Create paket.lock for reproducible builds
            Invoke-PaketForAL -Sources $nugetSources -PaketExePath $paketFolder -Verbose

            # Copy .app files from Packages folder to .alpackages folder for AL compiler
            $packagesFolder = Join-Path $currentAppFolder "Packages"
            if (Test-Path -Path $packagesFolder) {
                Get-ChildItem -Path $packagesFolder -Filter *.app -Recurse | ForEach-Object {
                    $targetPath = Join-Path $packagecachepath $_.Name
                    if (!(Test-Path -Path $targetPath)) {
                        Write-Host "Copy $($_.Name) to .alpackages"
                        Copy-Item -Path $_.FullName -Destination $packagecachepath -Force
                    }
                }
            }
        }
        finally {
            Pop-Location

            # Restore original app.json for TestApp
            if ($_ -eq "TestApp") {
                $originalAppJson = Join-Path $currentAppFolder "app.json"
                $backupAppJson = Join-Path $currentAppFolder "app.json.backup"
                if (Test-Path -Path $backupAppJson) {
                    Move-Item -Path $backupAppJson -Destination $originalAppJson -Force
                }
            }
        }
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
