#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create a .dep.app package containing an app and its dependencies

.DESCRIPTION
    Creates a .dep.app file in NAVX format that bundles a Business Central app with its dependencies.
    This is the format required by the BC Development API when DependencyPublishingOption=default.

    The NAVX format consists of:
    - NAVX header with metadata
    - ZIP content containing:
      - [Content_Types].xml: OPC manifest
      - projectDependencySet.json: BC dependency metadata
      - .app files with URL-encoded names

.PARAMETER AppPath
    Path to the main .app file

.PARAMETER DependencyPaths
    Array of paths to dependency .app files

.PARAMETER OutputPath
    Path where the .dep.app file will be created (optional - defaults to same folder as AppPath)

.EXAMPLE
    ./Create-DepApp.ps1 -AppPath "./TestApp/MyApp.app" -DependencyPaths @("./App/Dependency.app")

.EXAMPLE
    ./Create-DepApp.ps1 -AppPath "./TestApp/MyApp.app" -DependencyPaths @("./App/Dep1.app", "./App/Dep2.app") -OutputPath "./TestApp/MyApp.dep.app"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$AppPath,

    [Parameter(Mandatory = $false)]
    [AllowEmptyCollection()]
    [string[]]$DependencyPaths = @(),

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

function New-NavxPackage {
    param(
        [string]$ZipFilePath,
        [string]$OutputPath,
        [Guid]$PackageId
    )

    # Read the ZIP content
    $zipContent = [System.IO.File]::ReadAllBytes($ZipFilePath)
    $contentLength = $zipContent.Length

    # Calculate metadata size (header size)
    $metadataSize = 40  # Fixed size: 4+4+4+16+8+4+2 bytes

    # Create NAVX header
    $memoryStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.BinaryWriter]::new($memoryStream)

    try {
        # Magic number 1: "NAVX" = 0x5856414E in little-endian
        $writer.Write([UInt32]0x5856414E)

        # Metadata size
        $writer.Write([UInt32]$metadataSize)

        # Metadata version
        $writer.Write([UInt32]2)

        # Package ID (16 bytes)
        $writer.Write($PackageId.ToByteArray())

        # Content length (8 bytes)
        $writer.Write([Int64]$contentLength)

        # Magic number 2: "NAVX" = 0x5856414E
        $writer.Write([UInt32]0x5856414E)

        # Write the ZIP content (starts immediately after header at byte 40)
        # The ZIP signature "PK" (0x50 0x4B) appears at this position
        $writer.Write($zipContent)

        # Write to output file
        $writer.Flush()
        [System.IO.File]::WriteAllBytes($OutputPath, $memoryStream.ToArray())
    }
    finally {
        $writer.Dispose()
        $memoryStream.Dispose()
    }
}

function Get-AppInfo {
    param([string]$AppFilePath)

    # Use AL tool to extract manifest from .app file (returns JSON)
    $manifestOutput = al GetPackageManifest "$AppFilePath" 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read manifest from $AppFilePath. Error: $manifestOutput"
    }

    # Join the output lines and parse JSON
    $manifestJson = $manifestOutput -join "`n"
    $manifest = $manifestJson | ConvertFrom-Json

    return @{
        AppId     = $manifest.id
        Name      = $manifest.name
        Publisher = $manifest.publisher
        Version   = $manifest.version
    }
}

function New-DepAppPackage {
    param(
        [string]$MainAppPath,
        [string[]]$DependencyAppPaths,
        [string]$DepAppOutputPath
    )

    Write-Host "Creating .dep.app package..." -ForegroundColor Cyan

    # Validate input files exist
    if (-not (Test-Path $MainAppPath)) {
        throw "Main app file not found: $MainAppPath"
    }

    foreach ($depPath in $DependencyAppPaths) {
        if (-not (Test-Path $depPath)) {
            throw "Dependency file not found: $depPath"
        }
    }

    # Get app information
    Write-Host "  Reading app metadata..." -ForegroundColor Gray
    $mainAppInfo = Get-AppInfo -AppFilePath $MainAppPath
    Write-Host "    Main app: $($mainAppInfo.Name) v$($mainAppInfo.Version)" -ForegroundColor Gray

    $dependencyInfos = @()
    foreach ($depPath in $DependencyAppPaths) {
        $depInfo = Get-AppInfo -AppFilePath $depPath
        $dependencyInfos += $depInfo
        Write-Host "    Dependency: $($depInfo.Name) v$($depInfo.Version)" -ForegroundColor Gray
    }

    # Create temporary directory for package contents
    # Use cross-platform temp directory (TEMP on Windows, TMPDIR or /tmp on Linux)
    $tempBase = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
    $tempDir = Join-Path $tempBase "dep_package_$(New-Guid)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    if (-not (Test-Path $tempDir)) {
        throw "Failed to create temporary directory: $tempDir"
    }

    try {
        # Copy main app with URL-encoded name (use app name from metadata, not filename)
        $mainAppFileName = "$($mainAppInfo.Name).app"
        $encodedMainAppName = [System.Uri]::EscapeDataString($mainAppFileName)
        Copy-Item $MainAppPath -Destination (Join-Path $tempDir $encodedMainAppName)
        Write-Host "  Added: $mainAppFileName (as $encodedMainAppName)" -ForegroundColor Gray

        # Copy dependency apps with URL-encoded names (use app name from metadata, not filename)
        for ($i = 0; $i -lt $DependencyAppPaths.Length; $i++) {
            $depPath = $DependencyAppPaths[$i]
            $depInfo = $dependencyInfos[$i]
            $depFileName = "$($depInfo.Name).app"
            $encodedDepName = [System.Uri]::EscapeDataString($depFileName)
            Copy-Item $depPath -Destination (Join-Path $tempDir $encodedDepName)
            Write-Host "  Added: $depFileName (as $encodedDepName)" -ForegroundColor Gray
        }

        # Create [Content_Types].xml
        $contentTypesXml = @'
<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="app" ContentType="" /><Default Extension="json" ContentType="" /></Types>
'@
        $contentTypesPath = Join-Path $tempDir "[Content_Types].xml"
        $contentTypesXml | Out-File -LiteralPath $contentTypesPath -Encoding utf8 -NoNewline
        Write-Host "  Added: [Content_Types].xml" -ForegroundColor Gray

        # Create projectDependencySet.json
        $projectReferences = @()

        # Add entries for each dependency
        foreach ($depInfo in $dependencyInfos) {
            $projectReferences += @{
                ThisProject                                  = @{
                    AppId     = $depInfo.AppId
                    Name      = $depInfo.Name
                    Publisher = $depInfo.Publisher
                    Version   = $depInfo.Version
                }
                ProjectsThatThisProjectDirectlyDependsOn     = @()
                ProjectsThatThisProjectTransitivelyDependsOn = @()
                ProjectsThatDirectlyDependOnThisProject      = @(
                    @{
                        AppId     = $mainAppInfo.AppId
                        Name      = $mainAppInfo.Name
                        Publisher = $mainAppInfo.Publisher
                        Version   = $mainAppInfo.Version
                    }
                )
                ProjectsThatTransitivelyDependOnThisProject  = @(
                    @{
                        AppId     = $mainAppInfo.AppId
                        Name      = $mainAppInfo.Name
                        Publisher = $mainAppInfo.Publisher
                        Version   = $mainAppInfo.Version
                    }
                )
            }
        }

        # Create dependency metadata
        $dependencySet = @{
            ProjectReferences = $projectReferences
            StartupProject    = @{
                ThisProject                                  = @{
                    AppId     = $mainAppInfo.AppId
                    Name      = $mainAppInfo.Name
                    Publisher = $mainAppInfo.Publisher
                    Version   = $mainAppInfo.Version
                }
                ProjectsThatThisProjectDirectlyDependsOn     = @(
                    $dependencyInfos | ForEach-Object {
                        @{
                            AppId     = $_.AppId
                            Name      = $_.Name
                            Publisher = $_.Publisher
                            Version   = $_.Version
                        }
                    }
                )
                ProjectsThatThisProjectTransitivelyDependsOn = @(
                    $dependencyInfos | ForEach-Object {
                        @{
                            AppId     = $_.AppId
                            Name      = $_.Name
                            Publisher = $_.Publisher
                            Version   = $_.Version
                        }
                    }
                )
                ProjectsThatDirectlyDependOnThisProject      = @()
                ProjectsThatTransitivelyDependOnThisProject  = @()
            }
        }

        $dependencySetJson = $dependencySet | ConvertTo-Json -Depth 10 -Compress
        $dependencySetJson | Out-File (Join-Path $tempDir "projectDependencySet.json") -Encoding utf8 -NoNewline
        Write-Host "  Added: projectDependencySet.json" -ForegroundColor Gray

        # Create temporary ZIP file using .NET ZipFile for cross-platform compatibility
        # Use manual entry creation to control compression level and file ordering
        $tempZipPath = Join-Path $tempBase "temp_package_$(New-Guid).zip"
        if (Test-Path $tempZipPath) {
            Remove-Item $tempZipPath -Force
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::Open($tempZipPath, 'Create')

        try {
            # Add files in sorted order for consistency
            $filesToZip = Get-ChildItem $tempDir | Sort-Object Name

            foreach ($file in $filesToZip) {
                $entryName = $file.Name
                $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::SmallestSize)

                $entryStream = $entry.Open()
                $fileStream = [System.IO.File]::OpenRead($file.FullName)
                $fileStream.CopyTo($entryStream)
                $fileStream.Close()
                $entryStream.Close()
            }
        }
        finally {
            $zip.Dispose()
        }

        # Generate a new package ID for the .dep.app
        $packageId = [Guid]::NewGuid()

        # Convert ZIP to NAVX format
        if (Test-Path $DepAppOutputPath) {
            Remove-Item $DepAppOutputPath -Force
        }

        New-NavxPackage -ZipFilePath $tempZipPath -OutputPath $DepAppOutputPath -PackageId $packageId
        Remove-Item $tempZipPath -Force

        Write-Host "Created: $DepAppOutputPath" -ForegroundColor Green

        # Verify the file was created
        if (Test-Path $DepAppOutputPath) {
            $fileSize = (Get-Item $DepAppOutputPath).Length
            Write-Host "  Size: $([math]::Round($fileSize / 1KB, 2)) KB" -ForegroundColor Gray
            return $true
        }
        else {
            throw "Failed to create .dep.app file"
        }
    }
    finally {
        # Cleanup temp directory
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
    }
}

# Main execution
try {
    # Resolve paths
    $resolvedAppPath = Resolve-Path $AppPath -ErrorAction Stop

    # Determine output path
    if (-not $OutputPath) {
        $appDir = Split-Path $resolvedAppPath -Parent
        $appBaseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedAppPath)
        $OutputPath = Join-Path $appDir "$appBaseName.dep.app"
    }

    # Resolve dependency paths
    $resolvedDependencyPaths = @()
    foreach ($depPath in $DependencyPaths) {
        $resolvedDependencyPaths += Resolve-Path $depPath -ErrorAction Stop
    }

    # Create the package
    $result = New-DepAppPackage -MainAppPath $resolvedAppPath `
        -DependencyAppPaths $resolvedDependencyPaths `
        -DepAppOutputPath $OutputPath

    if ($result) {
        Write-Host "`n✓ Successfully created .dep.app package" -ForegroundColor Green
        Write-Output $OutputPath
        exit 0
    }
    else {
        Write-Host "`n✗ Failed to create .dep.app package" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "`n✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
