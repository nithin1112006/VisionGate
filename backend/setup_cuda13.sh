#!/bin/bash
# Script to install CUDA 13.x compatible PyTorch and ONNX Runtime GPU
# for Blackwell GPUs (RTX 5070 / sm_120) on Linux.

echo "=== Uninstalling existing PyTorch and ONNX Runtime packages ==="
pip uninstall -y torch torchvision torchaudio onnxruntime onnxruntime-gpu

echo "=== Installing PyTorch with Blackwell (sm_120) support ==="
# Installs PyTorch with CUDA 12.8/13.x compatibility for RTX 5070 (Blackwell)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

echo "=== Installing ONNX Runtime GPU ==="
# Installs ONNX Runtime GPU built against CUDA 12/13
pip install coloredlogs flatbuffers numpy packaging protobuf sympy
# Attempt to install nightly ORT CUDA 12/13 build, or fallback to stable onnxruntime-gpu
pip install --pre --index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/ort-cuda-12-nightly/pypi/simple/ onnxruntime-gpu || pip install onnxruntime-gpu

echo "=== System Requirements Note ==="
echo "Note: RTX 5070 (Blackwell architecture) requires CUDA 12.8+ or 13.x and cuDNN 9.x to be installed on the system."
echo "Please make sure your CUDA Toolkit path and cuDNN DLLs/libraries are added to your PATH / LD_LIBRARY_PATH environment variables."

echo "=== Verifying CUDA & GPU support ==="
python3 -c "
import torch
print('PyTorch version:', torch.__version__)
print('CUDA available in PyTorch:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('Device Name:', torch.cuda.get_device_name(0))
    print('Device Capability:', torch.cuda.get_device_capability(0))
    print('Supported Architectures:', torch.cuda.get_arch_list() if hasattr(torch.cuda, 'get_arch_list') else 'N/A')

try:
    import onnxruntime as ort
    print('ONNX Runtime providers:', ort.get_available_providers())
    if 'CUDAExecutionProvider' in ort.get_available_providers():
        print('ONNX Runtime CUDA provider is available!')
    else:
        print('WARNING: ONNX Runtime CUDA provider is NOT available (Check cuDNN installation).')
except Exception as e:
    print('ONNX Runtime check failed:', e)
"
