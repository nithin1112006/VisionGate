#!/usr/bin/env bash
# ==============================================================================
# VisionGate / Attenda - Pre-Flight Deployment Doctor & System Diagnostics
# Diagnoses host OS, Docker, GPU, CUDA, Ports, Disk, and Configuration
# ==============================================================================
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BOLD}${BLUE} VisionGate / Attenda — Pre-Flight System Doctor                      ${NC}"
echo -e "${BLUE} Date: $(date) | Host: $(hostname)${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Helper functions
report_pass() {
    echo -e "  [${GREEN}✓ PASS${NC}] $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

report_warn() {
    echo -e "  [${YELLOW}! WARN${NC}] $1"
    echo -e "         ${CYAN}Notice:${NC} $2"
    WARN_COUNT=$((WARN_COUNT + 1))
}

report_fail() {
    echo -e "  [${RED}✗ FAIL${NC}] $1"
    echo -e "         ${RED}Reason:${NC} $2"
    echo -e "         ${YELLOW}Fix:${NC}    $3"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# 1. Operating System & Kernel
echo -e "\n${BOLD}[1/8] Operating System & Architecture${NC}"
ARCH=$(uname -m 2>/dev/null || echo "unknown")
if [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "aarch64" ]; then
    report_pass "CPU Architecture: ${ARCH}"
else
    report_warn "CPU Architecture: ${ARCH}" "VisionGate is optimized and validated for x86_64 and aarch64 architectures."
fi

if [ -f /etc/os-release ]; then
    OS_NAME=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    report_pass "Operating System: ${OS_NAME}"
else
    report_warn "Operating System info unavailable" "Unable to read /etc/os-release."
fi

# 2. System Hardware Resources
echo -e "\n${BOLD}[2/8] System Resources (RAM & Disk Space)${NC}"
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
if [ "$TOTAL_RAM_GB" -ge 8 ]; then
    report_pass "RAM: ${TOTAL_RAM_GB} GB (Sufficient for high-load attendance inference)"
elif [ "$TOTAL_RAM_GB" -ge 4 ]; then
    report_warn "RAM: ${TOTAL_RAM_GB} GB" "Recommended memory is $\ge$ 8 GB for high concurrent batch face recognition."
else
    report_fail "RAM: ${TOTAL_RAM_GB} GB" "Insufficient RAM for running PostgreSQL + PyTorch + InsightFace." "Upgrade host memory to at least 4-8 GB."
fi

AVAIL_DISK_MB=$(df -m . 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
AVAIL_DISK_GB=$((AVAIL_DISK_MB / 1024))
if [ "$AVAIL_DISK_GB" -ge 15 ]; then
    report_pass "Available Disk Space: ${AVAIL_DISK_GB} GB"
elif [ "$AVAIL_DISK_GB" -ge 5 ]; then
    report_warn "Available Disk Space: ${AVAIL_DISK_GB} GB" "Low disk space. Docker image builds require ~5-10 GB."
else
    report_fail "Available Disk Space: ${AVAIL_DISK_GB} GB" "Critically low disk space." "Free up at least 15 GB disk space before deployment."
fi

# 3. Docker Engine & Runtime
echo -e "\n${BOLD}[3/8] Docker Engine & Compose${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VER=$(docker --version)
    report_pass "Docker Engine installed: ${DOCKER_VER}"
    
    if docker info &> /dev/null; then
        report_pass "Docker daemon is running and accessible"
    else
        report_fail "Docker daemon not running / permission denied" "Cannot connect to docker.sock." "Run 'sudo systemctl start docker' or add your user to docker group: 'sudo usermod -aG docker \$USER'."
    fi
else
    report_fail "Docker not installed" "Docker is required for containerized deployment." "Install Docker via https://docs.docker.com/engine/install/ubuntu/ or 'sudo apt-get install -y docker.io'."
fi

COMPOSE_FOUND=0
if docker compose version &> /dev/null; then
    COMPOSE_VER=$(docker compose version --short)
    report_pass "Docker Compose v2 plugin detected: v${COMPOSE_VER}"
    COMPOSE_FOUND=1
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VER=$(docker-compose --version)
    report_pass "Docker Compose detected: ${COMPOSE_VER}"
    COMPOSE_FOUND=1
else
    report_fail "Docker Compose missing" "Docker Compose is required to manage the multi-container stack." "Install Compose plugin: 'sudo apt-get install -y docker-compose-v2'."
fi

# 4. GPU & NVIDIA Container Acceleration
echo -e "\n${BOLD}[4/8] NVIDIA GPU & Hardware Acceleration${NC}"
HAS_GPU=0
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || echo "Unknown GPU")
    DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 || echo "Unknown Driver")
    report_pass "NVIDIA GPU Detected: ${GPU_NAME} (Driver ${DRIVER_VER})"
    HAS_GPU=1

    if command -v nvidia-ctk &> /dev/null; then
        report_pass "NVIDIA Container Toolkit (nvidia-ctk) is installed"
    else
        report_warn "NVIDIA Container Toolkit not detected" "GPU passthrough into Docker containers may fail."
    fi

    # Test GPU container access
    if docker run --rm --gpus all nvidia/cuda:12.8.0-runtime-ubuntu24.04 nvidia-smi &> /dev/null; then
        report_pass "Docker GPU Container Passthrough is fully OPERATIONAL"
    elif docker run --rm --runtime=nvidia nvidia/cuda:12.8.0-runtime-ubuntu24.04 nvidia-smi &> /dev/null; then
        report_pass "Docker NVIDIA runtime passthrough is OPERATIONAL"
    else
        report_warn "Docker GPU passthrough test failed" "Container will run in CPU fallback mode unless nvidia-container-toolkit is configured: 'sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker'."
    fi
else
    report_warn "nvidia-smi not found on host" "System will run in CPU-only mode. Face recognition is fully supported on CPU with fallback execution providers."
fi

# 5. Network Port Availability
echo -e "\n${BOLD}[5/8] Network Ports Availability${NC}"
check_port() {
    local port=$1
    local name=$2
    if command -v lsof &> /dev/null; then
        if lsof -i ":${port}" &> /dev/null; then
            report_warn "Port ${port} (${name}) is currently in use" "If another instance of VisionGate is already running, this is expected."
        else
            report_pass "Port ${port} (${name}) is available"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":${port} "; then
            report_warn "Port ${port} (${name}) is currently in use" "Ensure no conflicting services occupy port ${port}."
        else
            report_pass "Port ${port} (${name}) is available"
        fi
    else
        report_pass "Port ${port} (${name}) check skipped (lsof/netstat not on host)"
    fi
}

check_port "${HTTP_PORT:-80}" "Nginx Reverse Proxy"
check_port "${BACKEND_PORT:-8001}" "FastAPI Backend"
check_port "${PG_HOST_PORT:-5432}" "PostgreSQL Port"

# 6. Environment Configuration (.env)
echo -e "\n${BOLD}[6/8] Environment Secrets & Configuration${NC}"
if [ -f .env ]; then
    report_pass ".env configuration file is present"
    
    # Check mandatory keys
    check_env_var() {
        local var_name=$1
        local is_secret=$2
        local val=$(grep -E "^${var_name}=" .env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "")
        if [ -n "$val" ]; then
            if [ "$is_secret" -eq 1 ]; then
                report_pass "Env variable: ${var_name} is configured (hidden)"
            else
                report_pass "Env variable: ${var_name}=${val}"
            fi
        else
            report_warn "Env variable: ${var_name} is empty or missing" "Default fallback will be used."
        fi
    }

    check_env_var "PG_DB" 0
    check_env_var "PG_USER" 0
    check_env_var "PG_PASSWORD" 1
    check_env_var "BACKEND_PORT" 0
    check_env_var "HTTP_PORT" 0
else
    if [ -f .env.example ]; then
        report_warn ".env file is missing" "Will be created automatically from .env.example during deploy."
    else
        report_fail "Neither .env nor .env.example found" "Repository environment templates are missing." "Restore .env.example from git repository."
    fi
fi

# 7. Cloudflare Configuration Check
echo -e "\n${BOLD}[7/8] Cloudflare Edge & Tunnel Integration${NC}"
CF_TOKEN=$(grep -E '^CLOUDFLARE_TUNNEL_TOKEN=' .env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "")
CF_DOMAIN=$(grep -E '^CLOUDFLARE_DOMAIN=' .env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "")

if [ -n "$CF_TOKEN" ]; then
    report_pass "Cloudflare Zero-Trust Tunnel Token is configured"
elif [ -n "$CF_DOMAIN" ]; then
    report_pass "Cloudflare DNS Proxy Domain is configured: ${CF_DOMAIN}"
else
    report_warn "Cloudflare Tunnel Token & Domain not set" "System can still run on local network / direct IP. Set CLOUDFLARE_TUNNEL_TOKEN in .env for public Zero-Trust domain access."
fi

# 8. Model & Static Assets
echo -e "\n${BOLD}[8/8] Static Assets & Model Dependencies${NC}"
if [ -f "backend/requirements.txt" ]; then
    report_pass "Backend requirements manifest present"
else
    report_fail "backend/requirements.txt missing" "Cannot build backend container without requirements manifest." "Restore backend/requirements.txt from repository."
fi

if [ -f "backend/Dockerfile" ]; then
    report_pass "Backend Dockerfile present"
else
    report_fail "backend/Dockerfile missing" "Cannot build container image." "Restore backend/Dockerfile from repository."
fi

if [ -f "docker/postgres/01-init.sql" ]; then
    report_pass "PostgreSQL initializer (01-init.sql) present"
else
    report_fail "docker/postgres/01-init.sql missing" "Database extensions will not be initialized." "Restore docker/postgres/01-init.sql from repository."
fi

# Summary
echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${BOLD} Pre-Flight Diagnostic Summary:${NC}"
echo -e "  Passed:   ${GREEN}${PASS_COUNT}${NC}"
echo -e "  Warnings: ${YELLOW}${WARN_COUNT}${NC}"
echo -e "  Failures: ${RED}${FAIL_COUNT}${NC}"
echo -e "${BLUE}======================================================================${NC}"

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ System is READY for VisionGate deployment.${NC}\n"
    exit 0
else
    echo -e "${RED}✗ Please fix the failed prerequisites above before proceeding.${NC}\n"
    exit 1
fi
