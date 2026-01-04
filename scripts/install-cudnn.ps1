<#
.SYNOPSIS
    Installs NVIDIA cuDNN for ONNX Runtime build.

.DESCRIPTION
    Downloads and extracts cuDNN to the specified location.

    IMPORTANT: cuDNN requires accepting NVIDIA's license agreement and cannot be
    downloaded directly without authentication. You have several options:

    1. Set CUDNN_DOWNLOAD_URL secret with a direct download URL (if you host the file)
    2. Download manually and upload to a private storage (Azure Blob, S3, etc.)
    3. Use the NVIDIA NGC CLI with authentication

    This script expects the CUDNN_DOWNLOAD_URL environment variable to contain
    a direct download URL for the cuDNN ZIP file.

.PARAMETER CudnnVersion
    The cuDNN version to install (e.g., "9.6.0")

.PARAMETER CudaVersionShort
    The CUDA version (major.minor) this cuDNN is for (e.g., "12.6")

.EXAMPLE
    $env:CUDNN_DOWNLOAD_URL = "https://your-storage.example.com/cudnn-windows-x64.zip"
    .\install-cudnn.ps1 -CudnnVersion "9.6.0" -CudaVersionShort "12.6"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$CudnnVersion,

    [Parameter(Mandatory = $true)]
    [string]$CudaVersionShort
)

$ErrorActionPreference = "Stop"

$installPath = "C:\tools\cudnn"

Write-Host "Installing cuDNN $CudnnVersion for CUDA $CudaVersionShort..."

# Check for download URL
$downloadUrl = $env:CUDNN_DOWNLOAD_URL

if ([string]::IsNullOrEmpty($downloadUrl)) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "CUDNN_DOWNLOAD_URL not set!" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "cuDNN requires accepting NVIDIA's license and cannot be downloaded directly."
    Write-Host ""
    Write-Host "To obtain cuDNN:"
    Write-Host "1. Go to: https://developer.nvidia.com/cudnn-downloads"
    Write-Host "2. Select: Windows, x86_64, ZIP"
    Write-Host "3. Select: CUDA $CudaVersionShort"
    Write-Host "4. Download the ZIP file"
    Write-Host "5. Host it on your own storage (Azure Blob, S3, etc.)"
    Write-Host "6. Set the CUDNN_DOWNLOAD_URL secret in your GitHub repository"
    Write-Host ""
    Write-Host "Expected filename pattern: cudnn-windows-x86_64-${CudnnVersion}*-cuda${CudaVersionShort}*.zip"
    Write-Host ""

    # Try alternative: check if CUDA installation includes cuDNN (some installers do)
    $cudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$CudaVersionShort"
    $cudnnHeader = Join-Path $cudaPath "include\cudnn.h"

    if (Test-Path $cudnnHeader) {
        Write-Host "Found cuDNN bundled with CUDA installation at: $cudaPath" -ForegroundColor Green
        Write-Host "Creating symlink to CUDA path..."

        New-Item -ItemType Directory -Force -Path (Split-Path $installPath -Parent) | Out-Null

        # Create directory structure that mimics standalone cuDNN
        New-Item -ItemType Directory -Force -Path $installPath | Out-Null
        New-Item -ItemType SymbolicLink -Force -Path "$installPath\include" -Target "$cudaPath\include" | Out-Null
        New-Item -ItemType SymbolicLink -Force -Path "$installPath\lib" -Target "$cudaPath\lib\x64" | Out-Null
        New-Item -ItemType SymbolicLink -Force -Path "$installPath\bin" -Target "$cudaPath\bin" | Out-Null

        Write-Host "cuDNN setup completed using CUDA bundled version."
        exit 0
    }

    Write-Error "CUDNN_DOWNLOAD_URL environment variable is not set and cuDNN not found in CUDA installation."
    exit 1
}

# Download cuDNN
$zipPath = "$env:TEMP\cudnn.zip"

Write-Host "Downloading cuDNN from provided URL..."
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
}
catch {
    Write-Error "Failed to download cuDNN: $_"
    exit 1
}

Write-Host "Downloaded cuDNN archive: $((Get-Item $zipPath).Length / 1MB) MB"

# Create installation directory
New-Item -ItemType Directory -Force -Path $installPath | Out-Null

# Extract cuDNN
Write-Host "Extracting cuDNN to: $installPath"
$tempExtract = "$env:TEMP\cudnn_extract"
Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force

# Find the extracted folder (it's usually named cudnn-windows-x86_64-version...)
$extractedFolder = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1

if ($null -eq $extractedFolder) {
    # Files might be directly in the temp folder
    $extractedFolder = Get-Item $tempExtract
}

# Copy contents to installation path
$sourcePath = $extractedFolder.FullName

# Handle different ZIP structures
if (Test-Path "$sourcePath\include") {
    # Standard structure
    Copy-Item -Path "$sourcePath\*" -Destination $installPath -Recurse -Force
}
elseif (Test-Path "$sourcePath\cudnn\include") {
    # Nested structure
    Copy-Item -Path "$sourcePath\cudnn\*" -Destination $installPath -Recurse -Force
}
else {
    # Try to find include folder
    $includeDir = Get-ChildItem -Path $sourcePath -Recurse -Directory -Filter "include" | Select-Object -First 1
    if ($includeDir) {
        $parentDir = Split-Path $includeDir.FullName -Parent
        Copy-Item -Path "$parentDir\*" -Destination $installPath -Recurse -Force
    }
    else {
        Write-Error "Could not find cuDNN structure in extracted archive"
        exit 1
    }
}

# Verify installation
$cudnnHeader = Join-Path $installPath "include\cudnn.h"
if (-not (Test-Path $cudnnHeader)) {
    # Try alternate location
    $cudnnHeader = Join-Path $installPath "include\cudnn_version.h"
}

if (Test-Path $cudnnHeader) {
    Write-Host "cuDNN header found at: $cudnnHeader"

    # Try to read version
    $versionContent = Get-Content $cudnnHeader -Raw -ErrorAction SilentlyContinue
    if ($versionContent -match 'CUDNN_MAJOR\s+(\d+)') {
        $major = $Matches[1]
        if ($versionContent -match 'CUDNN_MINOR\s+(\d+)') {
            $minor = $Matches[1]
            Write-Host "Detected cuDNN version: $major.$minor"
        }
    }
}
else {
    Write-Warning "Could not verify cuDNN installation - header not found"
    Write-Host "Contents of $installPath :"
    Get-ChildItem -Path $installPath -Recurse | ForEach-Object { Write-Host $_.FullName }
}

# List installed files
Write-Host ""
Write-Host "cuDNN installation contents:"
Get-ChildItem -Path $installPath -Recurse -File | ForEach-Object {
    Write-Host "  $($_.FullName.Replace($installPath, ''))"
}

# Clean up
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "cuDNN $CudnnVersion installation completed at: $installPath"
