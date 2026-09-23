#!/usr/bin/env bash
# ==============================================================================
# VisionGate - Complete 360° System Health & Diagnostic Collector
# Executes non-destructive audits of OS, GPU, Services, Nginx, DB, and Auth
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=============================================================================="
echo "  VisionGate Complete 360° Linux Server Diagnostic Report"
echo "  Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "  Host:      $(hostname) ($(uname -srm))"
echo "=============================================================================="

# 1. Host Resources & Virtualenv
echo -e "\n${BLUE}[1/7] Host Architecture & Resource Status${NC}"
echo "--------------------------------------------------"
uptime
free -h | awk 'NR<=2'
df -h / | awk 'NR<=2'

# 2. Git & Working Tree Parity
echo -e "\n${BLUE}[2/7] Repository & Branch State${NC}"
echo "--------------------------------------------------"
cd /var/www/attenda/VisionGate 2>/dev/null || cd "$(dirname "$0")/../.."
echo "Path:         $(pwd)"
echo "Branch:       $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"
echo "Commit:       $(git log -1 --oneline 2>/dev/null || echo 'N/A')"
echo "Local Diffs:  $(git status --short 2>/dev/null || echo 'N/A')"

# 3. GPU & CUDA Acceleration
echo -e "\n${BLUE}[3/7] NVIDIA GPU & PyTorch Acceleration${NC}"
echo "--------------------------------------------------"
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used,utilization.gpu --format=csv,noheader
else
    echo "nvidia-smi not detected."
fi

VENV_PY="backend/venv/bin/python"
if [ -f "$VENV_PY" ]; then
    $VENV_PY -c "
import torch
print(f'PyTorch Version: {torch.__version__}')
print(f'CUDA Available:  {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'Device Name:     {torch.cuda.get_device_name(0)}')
" 2>/dev/null || echo "Virtual environment check failed."
fi

# 4. Systemd Services & Ports
echo -e "\n${BLUE}[4/7] Systemd Services & Network Listening Ports${NC}"
echo "--------------------------------------------------"
for svc in attenda-backend nginx cloudflared postgresql; do
    STATE=$(systemctl is-active $svc 2>/dev/null || echo "inactive/missing")
    ENABLED=$(systemctl is-enabled $svc 2>/dev/null || echo "unknown")
    echo "Service: $svc -> State: $STATE ($ENABLED)"
done

echo -e "\nListening Ports (Backend 8001, Nginx 80, Postgres 5432/5434):"
sudo ss -tlpn | grep -E ':(8001|80|5432|5434)\b' || true

# 5. Local & Reverse Proxy Health Probes
echo -e "\n${BLUE}[5/7] Endpoint Connectivity & Redirection Probes${NC}"
echo "--------------------------------------------------"
echo -n "FastAPI Direct (http://127.0.0.1:8001/health): "
curl -s -o /dev/null -w "HTTP %{http_code} (time: %{time_total}s)\n" http://127.0.0.1:8001/health || echo "FAILED"

echo -n "Nginx Proxy (http://127.0.0.1/healthz):        "
curl -s -o /dev/null -w "HTTP %{http_code} (time: %{time_total}s)\n" http://127.0.0.1/healthz || echo "FAILED"

echo -n "Public Gateway (https://app.srishakthicgpa.in/healthz): "
curl -s -o /dev/null -w "HTTP %{http_code} (time: %{time_total}s)\n" https://app.srishakthicgpa.in/healthz 2>/dev/null || echo "FAILED / UNREACHABLE"

echo -n "Public Gateway (https://app.srishakthi.in/healthz):     "
curl -s -o /dev/null -w "HTTP %{http_code} (time: %{time_total}s)\n" https://app.srishakthi.in/healthz 2>/dev/null || echo "FAILED / UNREACHABLE"

# 6. Database Schema & Accounts Audit
echo -e "\n${BLUE}[6/7] PostgreSQL Database & Authentication Audit${NC}"
echo "--------------------------------------------------"
if [ -f "deploy/native_linux/diagnose_and_repair_auth.py" ] && [ -f "$VENV_PY" ]; then
    $VENV_PY deploy/native_linux/diagnose_and_repair_auth.py --audit 2>/dev/null || true
else
    echo "Running direct SQL table count probe:"
    sudo -u postgres psql -d attenda -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null && echo "public tables found." || echo "PostgreSQL query failed."
fi

# 7. Live Systemd Errors & Journal Tail
echo -e "\n${BLUE}[7/7] Recent Backend & Nginx Error Logs${NC}"
echo "--------------------------------------------------"
echo ">> Last 25 lines of journalctl for attenda-backend:"
sudo journalctl -u attenda-backend -n 25 --no-pager 2>/dev/null || true

echo -e "\n>> Last 15 lines of Nginx error log:"
sudo tail -n 15 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error log entries."

echo -e "\n=============================================================================="
echo "  End of Diagnostic Report"
echo "=============================================================================="
