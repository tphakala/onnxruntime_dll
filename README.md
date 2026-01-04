# ONNX Runtime Multi-EP Windows Builds

Pre-built ONNX Runtime DLLs for Windows x64 with multiple execution providers (EPs) enabled in a single build.

## What This Provides

This repository builds ONNX Runtime from source with the following execution providers enabled:

| Execution Provider | Hardware Target | Description |
|-------------------|-----------------|-------------|
| **CPU** | Any x64 CPU | Default provider, always available |
| **CUDA** | NVIDIA GPUs | GPU acceleration via CUDA |
| **TensorRT** | NVIDIA GPUs | Optimized inference via TensorRT |
| **OpenVINO** | Intel CPU/GPU/NPU | Intel hardware acceleration |

## Downloads

Download pre-built binaries from the [Releases](../../releases) page.

Release archives include:
- `onnxruntime.dll` - Main runtime library
- `onnxruntime_providers_shared.dll` - Shared EP infrastructure
- `onnxruntime_providers_cuda.dll` - CUDA EP plugin
- `onnxruntime_providers_tensorrt.dll` - TensorRT EP plugin
- `onnxruntime_providers_openvino.dll` - OpenVINO EP plugin
- Header files for C/C++ development
- SHA256 checksums

## Version Compatibility

| ONNX Runtime | CUDA | cuDNN | TensorRT | OpenVINO |
|--------------|------|-------|----------|----------|
| 1.22.0 | 12.6 | 9.6.0 | 10.7.0 | 2025.1.0 |

Check ONNX Runtime's official documentation for exact version requirements:
- [CUDA EP Requirements](https://onnxruntime.ai/docs/execution-providers/CUDA-ExecutionProvider.html)
- [TensorRT EP Requirements](https://onnxruntime.ai/docs/execution-providers/TensorRT-ExecutionProvider.html)
- [OpenVINO EP Requirements](https://onnxruntime.ai/docs/execution-providers/OpenVINO-ExecutionProvider.html)

## Runtime Requirements

### For CPU Execution Provider
- Windows 10/11 x64
- Visual C++ Redistributable 2022

### For CUDA/TensorRT Execution Providers
- NVIDIA GPU with Compute Capability 5.0+
- NVIDIA Driver 550.0+ (for CUDA 12.6)
- cuDNN and TensorRT runtime libraries (included with NVIDIA drivers or downloadable separately)

### For OpenVINO Execution Provider
- Intel CPU (6th Gen+), Intel GPU, or Intel NPU
- OpenVINO runtime (can be installed via pip: `pip install openvino`)

## Usage

### Basic Setup

1. Extract the release archive
2. Place all DLLs in the same directory as your executable
3. Include the header files in your project

### C++ Example

```cpp
#include <onnxruntime_cxx_api.h>

int main() {
    Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "example");
    Ort::SessionOptions session_options;

    // Use CUDA EP (falls back to CPU if unavailable)
    OrtCUDAProviderOptions cuda_options{};
    session_options.AppendExecutionProvider_CUDA(cuda_options);

    // Or use TensorRT EP
    // OrtTensorRTProviderOptions trt_options{};
    // session_options.AppendExecutionProvider_TensorRT(trt_options);

    // Or use OpenVINO EP
    // session_options.AppendExecutionProvider_OpenVINO("CPU");

    Ort::Session session(env, L"model.onnx", session_options);

    // ... run inference
}
```

### Python Example

```python
import onnxruntime as ort

# List available providers
print(ort.get_available_providers())

# Create session with CUDA
session = ort.InferenceSession(
    "model.onnx",
    providers=['CUDAExecutionProvider', 'CPUExecutionProvider']
)

# Or with TensorRT
session = ort.InferenceSession(
    "model.onnx",
    providers=['TensorrtExecutionProvider', 'CUDAExecutionProvider', 'CPUExecutionProvider']
)

# Or with OpenVINO
session = ort.InferenceSession(
    "model.onnx",
    providers=['OpenVINOExecutionProvider', 'CPUExecutionProvider']
)
```

### Execution Provider Priority

When multiple EPs are available, ONNX Runtime uses them in the order specified. A typical priority order:

1. **TensorRT** - Best performance for supported ops on NVIDIA GPUs
2. **CUDA** - GPU acceleration for ops not supported by TensorRT
3. **OpenVINO** - Intel hardware acceleration
4. **CPU** - Fallback for remaining ops

```python
providers = [
    'TensorrtExecutionProvider',
    'CUDAExecutionProvider',
    'OpenVINOExecutionProvider',
    'CPUExecutionProvider'
]
session = ort.InferenceSession("model.onnx", providers=providers)
```

## Building Locally

### Prerequisites

- Windows 10/11 x64
- Visual Studio 2022 with C++ workload
- CMake 3.26+
- Python 3.10+
- Git

### Build Steps

1. Clone ONNX Runtime:
   ```powershell
   git clone --recursive https://github.com/microsoft/onnxruntime.git
   cd onnxruntime
   git checkout v1.22.0
   ```

2. Install CUDA Toolkit, cuDNN, TensorRT, and OpenVINO (see scripts/ folder)

3. Build with all EPs:
   ```powershell
   python tools\ci_build\build.py `
       --config Release `
       --build_shared_lib `
       --parallel `
       --use_cuda --cuda_home "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6" --cudnn_home "C:\tools\cudnn" `
       --use_tensorrt --tensorrt_home "C:\tools\tensorrt" `
       --use_openvino CPU `
       --cmake_generator "Visual Studio 17 2022"
   ```

4. Find outputs in `build\Windows\Release\Release\`

## GitHub Actions Workflow

This repository includes a GitHub Actions workflow that automates the build process.

### Triggering a Build

1. **Manual dispatch**: Go to Actions > Build ONNX Runtime Multi-EP > Run workflow
2. **Tag push**: Push a tag like `v1.22.0` to trigger a release build

### Required Secrets

Due to NVIDIA's licensing requirements, cuDNN and TensorRT cannot be downloaded directly. You must:

1. Download cuDNN and TensorRT from NVIDIA's developer portal
2. Host them on your own storage (Azure Blob, S3, etc.)
3. Add these secrets to your repository:
   - `CUDNN_DOWNLOAD_URL`: Direct URL to cuDNN ZIP
   - `TENSORRT_DOWNLOAD_URL`: Direct URL to TensorRT ZIP

### Caching

The workflow caches:
- CUDA Toolkit installation
- cuDNN files
- TensorRT files
- OpenVINO files

This significantly speeds up subsequent builds.

## Troubleshooting

### "DLL not found" errors

Ensure all required DLLs are in your application's directory or in PATH:
- `onnxruntime.dll`
- `onnxruntime_providers_shared.dll`
- Provider-specific DLLs

### CUDA EP not working

1. Verify NVIDIA driver version: `nvidia-smi`
2. Check CUDA installation: `nvcc --version`
3. Ensure GPU has sufficient compute capability

### TensorRT EP not working

1. TensorRT requires CUDA EP to also be available
2. Check TensorRT version compatibility
3. First inference may be slow (TensorRT engine building)

### OpenVINO EP not working

1. Install OpenVINO runtime: `pip install openvino`
2. Run OpenVINO's setupvars script to set environment
3. Check supported devices: `from openvino import Core; print(Core().available_devices)`

## License

This repository's build configuration is MIT licensed. See [LICENSE](LICENSE).

ONNX Runtime is licensed under the MIT License.
NVIDIA software (CUDA, cuDNN, TensorRT) is subject to NVIDIA's license agreements.
OpenVINO is licensed under Apache 2.0.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Links

- [ONNX Runtime Documentation](https://onnxruntime.ai/docs/)
- [ONNX Runtime GitHub](https://github.com/microsoft/onnxruntime)
- [NVIDIA Developer](https://developer.nvidia.com/)
- [Intel OpenVINO](https://docs.openvino.ai/)
