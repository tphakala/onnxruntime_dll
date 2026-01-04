<#
.SYNOPSIS
    Installs NVIDIA CUDA Toolkit for ONNX Runtime build.

.DESCRIPTION
    Downloads and installs CUDA Toolkit silently for CI/CD environments.
    Uses the network installer for smaller initial download.

.PARAMETER CudaVersion
    The full CUDA version to install (e.g., "12.6.3")

.EXAMPLE
    .\install-cuda.ps1 -CudaVersion "12.6.3"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$CudaVersion
)

$ErrorActionPreference = "Stop"

# Parse version components
$versionParts = $CudaVersion -split '\.'
$majorMinor = "$($versionParts[0]).$($versionParts[1])"
$majorMinorPatch = $CudaVersion

Write-Host "Installing CUDA Toolkit $CudaVersion..."

# CUDA download URL pattern
# Format: https://developer.download.nvidia.com/compute/cuda/{version}/network_installers/cuda_{version}_windows_network.exe
$cudaInstallerUrl = "https://developer.download.nvidia.com/compute/cuda/$majorMinorPatch/network_installers/cuda_${majorMinorPatch}_windows_network.exe"

# Alternative: local installer (larger but more reliable)
# $cudaInstallerUrl = "https://developer.download.nvidia.com/compute/cuda/$majorMinorPatch/local_installers/cuda_${majorMinorPatch}_windows.exe"

$installerPath = "$env:TEMP\cuda_installer.exe"

Write-Host "Downloading CUDA installer from: $cudaInstallerUrl"
try {
    $ProgressPreference = 'SilentlyContinue'  # Speeds up Invoke-WebRequest
    Invoke-WebRequest -Uri $cudaInstallerUrl -OutFile $installerPath -UseBasicParsing
}
catch {
    Write-Error "Failed to download CUDA installer: $_"
    exit 1
}

Write-Host "Downloaded installer to: $installerPath"
Write-Host "File size: $((Get-Item $installerPath).Length / 1MB) MB"

# CUDA silent install components
# See: https://docs.nvidia.com/cuda/cuda-installation-guide-microsoft-windows/index.html
$components = @(
    "nvcc_$majorMinor",
    "cuobjdump_$majorMinor",
    "nvprune_$majorMinor",
    "cupti_$majorMinor",
    "cublas_$majorMinor",
    "cublas_dev_$majorMinor",
    "cudart_$majorMinor",
    "cufft_$majorMinor",
    "cufft_dev_$majorMinor",
    "curand_$majorMinor",
    "curand_dev_$majorMinor",
    "cusolver_$majorMinor",
    "cusolver_dev_$majorMinor",
    "cusparse_$majorMinor",
    "cusparse_dev_$majorMinor",
    "npp_$majorMinor",
    "npp_dev_$majorMinor",
    "nvrtc_$majorMinor",
    "nvrtc_dev_$majorMinor",
    "nvml_dev_$majorMinor",
    "nvjpeg_$majorMinor",
    "nvjpeg_dev_$majorMinor",
    "thrust_$majorMinor",
    "visual_studio_integration_$majorMinor"
)

$componentArgs = $components -join " "

Write-Host "Installing CUDA components..."
Write-Host "Components: $componentArgs"

# Run silent installation
$installArgs = "-s $componentArgs"
$process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

if ($process.ExitCode -ne 0) {
    Write-Error "CUDA installation failed with exit code: $($process.ExitCode)"
    exit 1
}

# Verify installation
$cudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$majorMinor"
if (Test-Path $cudaPath) {
    Write-Host "CUDA installed successfully at: $cudaPath"

    # Verify nvcc
    $nvccPath = Join-Path $cudaPath "bin\nvcc.exe"
    if (Test-Path $nvccPath) {
        $nvccVersion = & $nvccPath --version 2>&1 | Select-String "release"
        Write-Host "nvcc version: $nvccVersion"
    }
}
else {
    Write-Error "CUDA installation directory not found: $cudaPath"
    exit 1
}

# Clean up
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

Write-Host "CUDA Toolkit $CudaVersion installation completed."
