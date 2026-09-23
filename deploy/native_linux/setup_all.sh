#!/usr/bin/env bash
# ==============================================================================
# VisionGate / Attenda - Master Native Linux Deployment Orchestrator
# Executes full bare-metal setup for PostgreSQL 16, Python 3.12 Backend with GPU,
# Nginx Reverse Proxy, and Cloudflare Tunnel with zero Docker containers.
# Usage: sudo bash setup_all.sh
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run setup_all.sh with sudo or as root.${NC}"
    echo -e "Usage: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Execute unified repair and deploy engine
bash "${SCRIPT_DIR}/repair_and_deploy.sh"
