#!/usr/bin/env bash
# ==============================================================================
# GPU Diagnostic & Passthrough Verification Script
# Target: Ubuntu 24.04 LTS | NVIDIA RTX 5070 (Blackwell sm_120)
# ==============================================================================
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE} Attenda GPU & Docker Passthrough Verification Tool${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Step 1: Check host NVIDIA driver
echo -e "\n${YELLOW}[1/4] Checking Host NVIDIA Driver...${NC}"
if command -v nvidia-smi &> /dev/null; then
    NVIDIA_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
    CUDA_VER=$(nvidia-smi | grep -o "CUDA Version: [0-9.]*" | head -n1)
    echo -e "  ${GREEN}✓${NC} Detected GPU: ${GREEN}${GPU_NAME}${NC}"
    echo -e "  ${GREEN}✓${NC} Driver Version: ${GREEN}${NVIDIA_DRIVER}${NC}"
    echo -e "  ${GREEN}✓${NC} ${CUDA_VER}"
else
    echo -e "  ${RED}✗ nvidia-smi not found! Please install the official NVIDIA Linux drivers.${NC}"
    exit 1
fi

# Step 2: Check Docker and NVIDIA Container Toolkit
echo -e "\n${YELLOW}[2/4] Checking Docker & NVIDIA Container Toolkit...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "  ${RED}✗ Docker is not installed.${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Docker Version: $(docker --version)"

# Step 3: Test NVIDIA GPU Passthrough with Docker
echo -e "\n${YELLOW}[3/4] Testing GPU passthrough in temporary container...${NC}"
if docker run --rm --gpus all nvidia/cuda:12.8.0-runtime-ubuntu24.04 nvidia-smi &> /dev/null; then
    echo -e "  ${GREEN}✓ NVIDIA GPU container passthrough is operational.${NC}"
else
    echo -e "  ${YELLOW}! Standard --gpus test failed. Testing with nvidia-container-toolkit runtime...${NC}"
    if docker run --rm --runtime=nvidia nvidia/cuda:12.8.0-runtime-ubuntu24.04 nvidia-smi &> /dev/null; then
        echo -e "  ${GREEN}✓ NVIDIA runtime passthrough is operational.${NC}"
    else
        echo -e "  ${RED}✗ GPU passthrough failed!${NC}"
        echo -e "  To fix, install and configure nvidia-container-toolkit:"
        echo -e "    sudo apt-get install -y nvidia-container-toolkit"
        echo -e "    sudo nvidia-ctk runtime configure --runtime=docker"
        echo -e "    sudo systemctl restart docker"
        exit 1
    fi
fi

# Step 4: Test PyTorch & ONNX Runtime CUDA Acceleration
echo -e "\n${YELLOW}[4/4] Verifying PyTorch and ONNX Runtime CUDA Acceleration in Attenda container...${NC}"
if docker image inspect attenda-backend:latest &> /dev/null; then
    docker run --rm --gpus all attenda-backend:latest python3 -c "
import torch
print('  PyTorch Version:', torch.__version__)
print('  CUDA is available in container:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('  Container GPU:', torch.cuda.get_device_name(0))
    print('  Compute Capability:', torch.cuda.get_device_capability(0))
else:
    sys.exit(1)

import onnxruntime as ort
providers = ort.get_available_providers()
print('  ONNX Providers:', providers)
assert 'CUDAExecutionProvider' in providers, 'CUDAExecutionProvider not found'
print('  ONNX GPU Acceleration: OPERATIONAL')
"
    echo -e "\n${GREEN}✓ All GPU and hardware acceleration checks passed successfully!${NC}"
else
    echo -e "  ${YELLOW}Notice: 'attenda-backend:latest' image not built yet.${NC}"
    echo -e "  Run 'bash scripts/deploy.sh' to build and start the system."
fi
