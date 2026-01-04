<#
.SYNOPSIS
    Installs NVIDIA TensorRT for ONNX Runtime build.

.DESCRIPTION
    Downloads and extracts TensorRT to the specified location.

    IMPORTANT: TensorRT requires accepting NVIDIA's license agreement and cannot be
    downloaded directly without authentication. You have several options:

    1. Set TENSORRT_DOWNLOAD_URL secret with a direct download URL (if you host the file)
    2. Download manually and upload to private storage (Azure Blob, S3, etc.)
    3. Use NVIDIA NGC CLI with authentication

    This script expects the TENSORRT_DOWNLOAD_URL environment variable to contain
    a direct download URL for the TensorRT ZIP file.

.PARAMETER TensorrtVersion
    The TensorRT version to install (e.g., "10.7.0.23")

.PARAMETER CudaVersionShort
    The CUDA version (major.minor) this TensorRT is for (e.g., "12.6")

.EXAMPLE
    $env:TENSORRT_DOWNLOAD_URL = "https://your-storage.example.com/tensorrt-windows.zip"
    .\install-tensorrt.ps1 -TensorrtVersion "10.7.0.23" -CudaVersionShort "12.6"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TensorrtVersion,

    [Parameter(Mandatory = $true)]
    [string]$CudaVersionShort
)

$ErrorActionPreference = "Stop"

$installPath = "C:\tools\tensorrt"

Write-Host "Installing TensorRT $TensorrtVersion for CUDA $CudaVersionShort..."

# Check for download URL
$downloadUrl = $env:TENSORRT_DOWNLOAD_URL

if ([string]::IsNullOrEmpty($downloadUrl)) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "TENSORRT_DOWNLOAD_URL not set!" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "TensorRT requires accepting NVIDIA's license and cannot be downloaded directly."
    Write-Host ""
    Write-Host "To obtain TensorRT:"
    Write-Host "1. Go to: https://developer.nvidia.com/tensorrt/download"
    Write-Host "2. Select TensorRT $TensorrtVersion"
    Write-Host "3. Select: Windows, ZIP"
    Write-Host "4. Download the ZIP file for CUDA $CudaVersionShort"
    Write-Host "5. Host it on your own storage (Azure Blob, S3, etc.)"
    Write-Host "6. Set the TENSORRT_DOWNLOAD_URL secret in your GitHub repository"
    Write-Host ""
    Write-Host "Expected filename pattern: TensorRT-${TensorrtVersion}.Windows.win10.cuda-${CudaVersionShort}.zip"
    Write-Host ""

    Write-Error "TENSORRT_DOWNLOAD_URL environment variable is not set."
    exit 1
}

# Download TensorRT
$zipPath = "$env:TEMP\tensorrt.zip"

Write-Host "Downloading TensorRT from provided URL..."
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
}
catch {
    Write-Error "Failed to download TensorRT: $_"
    exit 1
}

Write-Host "Downloaded TensorRT archive: $((Get-Item $zipPath).Length / 1MB) MB"

# Create installation directory
New-Item -ItemType Directory -Force -Path $installPath | Out-Null

# Extract TensorRT
Write-Host "Extracting TensorRT to: $installPath"
$tempExtract = "$env:TEMP\tensorrt_extract"
Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force

# Find the extracted folder (usually named TensorRT-version)
$extractedFolder = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1

if ($null -eq $extractedFolder) {
    Write-Error "Could not find extracted TensorRT folder"
    exit 1
}

$sourcePath = $extractedFolder.FullName

# Copy contents to installation path
Write-Host "Copying TensorRT files from: $sourcePath"
Copy-Item -Path "$sourcePath\*" -Destination $installPath -Recurse -Force

# Verify installation
$trtHeader = Join-Path $installPath "include\NvInfer.h"
$trtLib = Join-Path $installPath "lib\nvinfer.lib"
$trtDll = Join-Path $installPath "lib\nvinfer_10.dll"

$verificationPassed = $true

if (Test-Path $trtHeader) {
    Write-Host "TensorRT header found: $trtHeader"

    # Extract version from header
    $headerContent = Get-Content $trtHeader -Raw
    if ($headerContent -match 'NV_TENSORRT_MAJOR\s+(\d+)') {
        $major = $Matches[1]
        Write-Host "Detected TensorRT major version: $major"
    }
}
else {
    Write-Warning "TensorRT header not found: $trtHeader"
    $verificationPassed = $false
}

if (Test-Path $trtLib) {
    Write-Host "TensorRT library found: $trtLib"
}
else {
    Write-Warning "TensorRT library not found: $trtLib"
    # Check alternate locations
    $altLib = Get-ChildItem -Path $installPath -Recurse -Filter "nvinfer*.lib" | Select-Object -First 1
    if ($altLib) {
        Write-Host "Found alternate library: $($altLib.FullName)"
    }
    else {
        $verificationPassed = $false
    }
}

# List key directories
Write-Host ""
Write-Host "TensorRT installation structure:"
@("include", "lib", "bin") | ForEach-Object {
    $dir = Join-Path $installPath $_
    if (Test-Path $dir) {
        Write-Host "  $_/:"
        Get-ChildItem -Path $dir -File | Select-Object -First 10 | ForEach-Object {
            Write-Host "    $($_.Name)"
        }
        $count = (Get-ChildItem -Path $dir -File).Count
        if ($count -gt 10) {
            Write-Host "    ... and $($count - 10) more files"
        }
    }
}

# Install Python bindings if needed (optional)
$pythonDir = Join-Path $installPath "python"
if (Test-Path $pythonDir) {
    Write-Host ""
    Write-Host "TensorRT Python bindings available at: $pythonDir"
    Write-Host "Install with: pip install $pythonDir\tensorrt-*.whl"
}

# Clean up
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

if (-not $verificationPassed) {
    Write-Warning "TensorRT installation may be incomplete. Check the structure above."
}

Write-Host ""
Write-Host "TensorRT $TensorrtVersion installation completed at: $installPath"
