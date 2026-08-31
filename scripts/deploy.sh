#!/usr/bin/env bash
# ==============================================================================
# VisionGate / Attenda - Automated Linux Deployment Script
# Target: Ubuntu 24.04 LTS | Intel Core Ultra 9 285K | NVIDIA RTX 5070
# ==============================================================================
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE} VisionGate / Attenda - High-Performance Linux Production Deployer    ${NC}"
echo -e "${BLUE} Target: Ubuntu 24.04 LTS (x86_64) | NVIDIA GeForce RTX 5070          ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# 1. Prerequisite Checks
echo -e "\n${YELLOW}[Step 1/6] Validating System Prerequisites...${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed.${NC}"
    echo "Please install Docker on Ubuntu 24.04: https://docs.docker.com/engine/install/ubuntu/"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Docker: $(docker --version)"

# Check Docker Compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    echo -e "  ${GREEN}✓${NC} Docker Compose: $(docker compose version --short)"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    echo -e "  ${GREEN}✓${NC} Docker Compose: $(docker-compose --version)"
else
    echo -e "${RED}Docker Compose plugin is not installed.${NC}"
    echo "Install via: sudo apt-get install -y docker-compose-v2"
    exit 1
fi

# Check NVIDIA driver and GPU
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
    DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)
    echo -e "  ${GREEN}✓${NC} GPU Detected: ${CYAN}${GPU_NAME}${NC} (Driver ${DRIVER_VER})"
else
    echo -e "  ${YELLOW}! nvidia-smi not found. Running in CPU-only fallback mode.${NC}"
fi

# 2. NVIDIA Container Toolkit Setup Verification
echo -e "\n${YELLOW}[Step 2/6] Checking NVIDIA Container Toolkit...${NC}"
if command -v nvidia-ctk &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} nvidia-ctk is present."
else
    echo -e "  ${YELLOW}! nvidia-container-toolkit is not installed.${NC}"
    echo -e "    Attempting to install repository keys for Ubuntu 24.04..."
    if command -v sudo &> /dev/null; then
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg --yes || true
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list || true
        sudo apt-get update || true
        sudo apt-get install -y nvidia-container-toolkit || true
        sudo nvidia-ctk runtime configure --runtime=docker || true
        sudo systemctl restart docker || true
    fi
fi

# 3. Environment Configuration
echo -e "\n${YELLOW}[Step 3/6] Setting Up Environment Variables...${NC}"
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "  ${GREEN}✓${NC} Created .env from .env.example"
    else
        echo -e "  ${RED}Error: .env and .env.example not found.${NC}"
        exit 1
    fi
else
    echo -e "  ${GREEN}✓${NC} Existing .env configuration loaded."
fi

# 4. Building Containers
echo -e "\n${YELLOW}[Step 4/6] Building Production Container Images...${NC}"
echo -e "  -> Building VisionGate backend with CUDA 13.0 and InsightFace pre-caching..."
${COMPOSE_CMD} build backend

# 5. Starting Stack
echo -e "\n${YELLOW}[Step 5/6] Starting Multi-Container Services...${NC}"
${COMPOSE_CMD} up -d

# 6. Service Health Check & Wait Loop
echo -e "\n${YELLOW}[Step 6/6] Verifying Stack Health...${NC}"
echo "Waiting for services to report HEALTHY..."

MAX_WAIT=90
WAITED=0
BACKEND_OK=0

while [ "$WAITED" -lt "$MAX_WAIT" ]; do
    BACKEND_STATUS=$(docker inspect --format='{{json .State.Health.Status}}' attenda-backend 2>/dev/null || echo "\"starting\"")
    POSTGRES_STATUS=$(docker inspect --format='{{json .State.Health.Status}}' attenda-postgres 2>/dev/null || echo "\"starting\"")

    if [ "$BACKEND_STATUS" == "\"healthy\"" ] && [ "$POSTGRES_STATUS" == "\"healthy\"" ]; then
        BACKEND_OK=1
        break
    fi

    echo -e "  -> Service status: Postgres (${POSTGRES_STATUS}), Backend (${BACKEND_STATUS}) [${WAITED}s/${MAX_WAIT}s]"
    sleep 3
    WAITED=$((WAITED + 3))
done

echo ""
if [ "$BACKEND_OK" -eq 1 ]; then
    # Fetch host IP for display
    HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}  VISIONGATE / ATTENDA DEPLOYED SUCCESSFULLY!                         ${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "  ${CYAN}API Server (Direct):${NC}    http://${HOST_IP}:8001"
    echo -e "  ${CYAN}API Docs (Swagger):${NC}     http://${HOST_IP}:8001/docs"
    echo -e "  ${CYAN}Nginx Reverse Proxy:${NC}    http://${HOST_IP}:80"
    echo -e "  ${CYAN}PostgreSQL Database:${NC}    ${HOST_IP}:5432 (DB: attenda)"
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "To view live logs:        ${YELLOW}${COMPOSE_CMD} logs -f backend${NC}"
    echo -e "To run GPU diagnostics:   ${YELLOW}bash scripts/verify_gpu.sh${NC}"
    echo -e "To stop services:         ${YELLOW}${COMPOSE_CMD} down${NC}"
    echo -e "${GREEN}======================================================================${NC}"
else
    echo -e "${RED}Deployment timed out waiting for backend to become healthy.${NC}"
    echo -e "Check logs for debugging:"
    echo -e "  ${YELLOW}${COMPOSE_CMD} logs backend${NC}"
    echo -e "  ${YELLOW}${COMPOSE_CMD} logs postgres${NC}"
    exit 1
fi
