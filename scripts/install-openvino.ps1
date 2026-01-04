<#
.SYNOPSIS
    Installs Intel OpenVINO Toolkit for ONNX Runtime build.

.DESCRIPTION
    Downloads and extracts OpenVINO to the specified location.
    OpenVINO provides direct download links without requiring authentication.

.PARAMETER OpenvinoVersion
    The OpenVINO version to install (e.g., "2025.1.0")

.EXAMPLE
    .\install-openvino.ps1 -OpenvinoVersion "2025.1.0"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$OpenvinoVersion
)

$ErrorActionPreference = "Stop"

$installPath = "C:\tools\openvino"

Write-Host "Installing OpenVINO $OpenvinoVersion..."

# Parse version for URL construction
# OpenVINO archive naming: openvino_2025.1.0.zip or w_openvino_toolkit_windows_2025.1.0.17491.e89b3abcd3a_x86_64.zip
$versionParts = $OpenvinoVersion -split '\.'
$majorMinor = "$($versionParts[0]).$($versionParts[1])"

# Try multiple download URL patterns
$downloadUrls = @(
    # GitHub releases (preferred - direct download)
    "https://github.com/openvinotoolkit/openvino/releases/download/$OpenvinoVersion/openvino_$OpenvinoVersion.zip",
    "https://github.com/openvinotoolkit/openvino/releases/download/$OpenvinoVersion/w_openvino_toolkit_windows_${OpenvinoVersion}_x86_64.zip",

    # Storage archive
    "https://storage.openvinotoolkit.org/repositories/openvino/packages/$majorMinor/windows/w_openvino_toolkit_windows_${OpenvinoVersion}_x86_64.zip",
    "https://storage.openvinotoolkit.org/repositories/openvino/packages/$OpenvinoVersion/windows/w_openvino_toolkit_windows_${OpenvinoVersion}_x86_64.zip"
)

$zipPath = "$env:TEMP\openvino.zip"
$downloadSuccess = $false

foreach ($url in $downloadUrls) {
    Write-Host "Trying download URL: $url"
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        $downloadSuccess = $true
        Write-Host "Download successful from: $url"
        break
    }
    catch {
        Write-Host "  Failed: $($_.Exception.Message)"
    }
}

if (-not $downloadSuccess) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Could not download OpenVINO automatically" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please download OpenVINO manually:"
    Write-Host "1. Go to: https://www.intel.com/content/www/us/en/developer/tools/openvino-toolkit/download.html"
    Write-Host "2. Select: OpenVINO Archives, Windows, $OpenvinoVersion"
    Write-Host "3. Download the archive package (ZIP)"
    Write-Host ""
    Write-Host "Alternatively, check GitHub releases:"
    Write-Host "https://github.com/openvinotoolkit/openvino/releases/tag/$OpenvinoVersion"
    Write-Host ""

    Write-Error "Failed to download OpenVINO from any known URL."
    exit 1
}

Write-Host "Downloaded OpenVINO archive: $((Get-Item $zipPath).Length / 1MB) MB"

# Create installation directory
New-Item -ItemType Directory -Force -Path $installPath | Out-Null

# Extract OpenVINO
Write-Host "Extracting OpenVINO to: $installPath"
$tempExtract = "$env:TEMP\openvino_extract"
Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force

# Find the extracted folder
$extractedFolder = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1

if ($null -eq $extractedFolder) {
    Write-Error "Could not find extracted OpenVINO folder"
    exit 1
}

$sourcePath = $extractedFolder.FullName

# Check if there's a nested structure (some archives have w_openvino_toolkit_... folder inside)
$nestedFolder = Get-ChildItem -Path $sourcePath -Directory -Filter "w_openvino*" | Select-Object -First 1
if ($nestedFolder) {
    $sourcePath = $nestedFolder.FullName
}

Write-Host "Copying OpenVINO files from: $sourcePath"

# Copy contents to installation path
Copy-Item -Path "$sourcePath\*" -Destination $installPath -Recurse -Force

# Verify installation
$runtimeDir = Join-Path $installPath "runtime"
$cmakeDir = Join-Path $runtimeDir "cmake"
$includeDir = Join-Path $runtimeDir "include"
$libDir = Join-Path $runtimeDir "lib\intel64\Release"
$binDir = Join-Path $runtimeDir "bin\intel64\Release"

$verificationPassed = $true

if (Test-Path $cmakeDir) {
    Write-Host "OpenVINO CMake config found: $cmakeDir"
}
else {
    Write-Warning "OpenVINO CMake config not found: $cmakeDir"
    # Try alternate location
    $altCmake = Get-ChildItem -Path $installPath -Recurse -Directory -Filter "cmake" | Select-Object -First 1
    if ($altCmake) {
        Write-Host "Found alternate cmake location: $($altCmake.FullName)"
    }
    else {
        $verificationPassed = $false
    }
}

if (Test-Path $includeDir) {
    Write-Host "OpenVINO headers found: $includeDir"
}
else {
    Write-Warning "OpenVINO headers not found: $includeDir"
    $verificationPassed = $false
}

# List key components
Write-Host ""
Write-Host "OpenVINO installation structure:"

$keyDirs = @(
    @{ Path = "runtime\include"; Name = "Headers" },
    @{ Path = "runtime\lib\intel64\Release"; Name = "Libraries" },
    @{ Path = "runtime\bin\intel64\Release"; Name = "Binaries" },
    @{ Path = "runtime\cmake"; Name = "CMake" }
)

foreach ($dir in $keyDirs) {
    $fullPath = Join-Path $installPath $dir.Path
    if (Test-Path $fullPath) {
        Write-Host "  $($dir.Name) ($($dir.Path)):"
        Get-ChildItem -Path $fullPath -File | Select-Object -First 5 | ForEach-Object {
            Write-Host "    $($_.Name)"
        }
        $count = (Get-ChildItem -Path $fullPath -File).Count
        if ($count -gt 5) {
            Write-Host "    ... and $($count - 5) more files"
        }
    }
}

# Check for setupvars script
$setupVars = Join-Path $installPath "setupvars.bat"
if (Test-Path $setupVars) {
    Write-Host ""
    Write-Host "Environment setup script found: $setupVars"
}
else {
    # Try alternate locations
    $altSetup = Get-ChildItem -Path $installPath -Recurse -Filter "setupvars.bat" | Select-Object -First 1
    if ($altSetup) {
        Write-Host "Found setupvars.bat at: $($altSetup.FullName)"
    }
}

# Verify OpenVINO version file
$versionFile = Join-Path $installPath "runtime\include\openvino\openvino.hpp"
if (Test-Path $versionFile) {
    $versionContent = Get-Content $versionFile -Raw -ErrorAction SilentlyContinue
    Write-Host "OpenVINO core header found"
}

# Clean up
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

if (-not $verificationPassed) {
    Write-Warning "OpenVINO installation may be incomplete. Check the structure above."
}

Write-Host ""
Write-Host "OpenVINO $OpenvinoVersion installation completed at: $installPath"
Write-Host ""
Write-Host "To use OpenVINO in your build, set:"
Write-Host "  INTEL_OPENVINO_DIR=$installPath"
Write-Host "  OpenVINO_DIR=$installPath\runtime\cmake"
