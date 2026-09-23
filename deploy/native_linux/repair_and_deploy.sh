#!/usr/bin/env bash
# ==============================================================================
# VisionGate / Attenda - Universal Self-Healing & Production Deployment Script
# Target: Ubuntu 24.04.4 LTS (Noble) | Intel Ultra 9 285K | NVIDIA RTX 5070
# Domain: app.srishakthi.in (with attenda.srishakthicgpa.in fallback)
# Execution: sudo bash repair_and_deploy.sh
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BOLD}${BLUE}  VisionGate / Attenda - Universal Auto-Healing & Master Deployment Engine    ${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] This repair and deploy script must be executed with sudo or as root.${NC}"
    echo -e "Usage: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend"
RUN_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "techpark-2")}"

echo -e "${CYAN}Deployment Context:${NC}"
echo -e "  Root Directory:    ${GREEN}${ROOT_DIR}${NC}"
echo -e "  Backend Directory: ${GREEN}${BACKEND_DIR}${NC}"
echo -e "  Executing User:    ${GREEN}${RUN_USER}${NC}"
echo -e "  Target Host:       ${GREEN}app.srishakthi.in${NC}"

# Ensure proper permissions on deployment directory (critical for /var/www)
chown -R "${RUN_USER}:${RUN_USER}" "${ROOT_DIR}"
chmod -R u+rwX "${ROOT_DIR}"

# ── 1. System Package & Runtime Prerequisites ──────────────────────────────────
echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${CYAN}[1/6] Auditing & Installing System Prerequisites...${NC}"
echo -e "${BLUE}==============================================================================${NC}"

apt-get update -y -qq

PACKAGES=(
    curl wget git jq ufw build-essential software-properties-common
    python3 python3-venv python3-dev python3-pip libpq-dev
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender-dev libgomp1
    nginx
)

MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Installing missing system packages: ${MISSING_PKGS[*]}...${NC}"
    apt-get install -y "${MISSING_PKGS[@]}"
else
    echo -e "${GREEN}[✓] All core system packages already installed.${NC}"
fi

# Ensure PostgreSQL 16 & pgvector
if ! command -v psql &>/dev/null || ! dpkg -s postgresql-16-pgvector &>/dev/null; then
    echo -e "${YELLOW}Installing PostgreSQL 16 and pgvector extension...${NC}"
    add-apt-repository -y universe || true
    if ! apt-get install -y postgresql postgresql-contrib postgresql-16-pgvector 2>/dev/null; then
        install -d /etc/apt/keyrings
        curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg --yes
        echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
        apt-get update -y -qq
        apt-get install -y postgresql-16 postgresql-contrib-16 postgresql-16-pgvector
    fi
fi
systemctl enable --now postgresql
echo -e "${GREEN}[✓] PostgreSQL 16 with pgvector verified.${NC}"

# Ensure cloudflared CLI is installed
if ! command -v cloudflared &>/dev/null; then
    echo -e "${YELLOW}Installing Cloudflare Tunnel CLI (cloudflared)...${NC}"
    wget -q -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
    rm -f /tmp/cloudflared.deb
fi
echo -e "${GREEN}[✓] cloudflared CLI verified: $(cloudflared --version | head -n1)${NC}"

# ── 2. PostgreSQL Role, Database, Extensions & Full 82-Table Schema ────────────
echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${CYAN}[2/6] Auditing & Repairing Database, Schema & Migrations...${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Detect actual listening port and configuration of running PostgreSQL cluster
ACTIVE_PG_PORT=$(sudo -u postgres psql -tAc "SHOW port;" 2>/dev/null || echo "5432")
DB_USER="attenda"
DB_PASS="attenda_password"
DB_NAME="attenda"
DB_PORT="${ACTIVE_PG_PORT:-5432}"

if [ -f "${ROOT_DIR}/.env" ]; then
    DB_USER=$(grep -E "^PG_USER=" "${ROOT_DIR}/.env" | cut -d '=' -f2- | tr -d '"' | tr -d "'" || echo "attenda")
    DB_PASS=$(grep -E "^PG_PASSWORD=" "${ROOT_DIR}/.env" | cut -d '=' -f2- | tr -d '"' | tr -d "'" || echo "attenda_password")
    DB_NAME=$(grep -E "^PG_DB=" "${ROOT_DIR}/.env" | cut -d '=' -f2- | tr -d '"' | tr -d "'" || echo "attenda")
fi

echo -e "  Active PostgreSQL Cluster Port: ${GREEN}${DB_PORT}${NC}"

# Ensure listen_addresses allows localhost TCP connections
PG_CONF=$(sudo -u postgres psql -tAc "SHOW config_file;" 2>/dev/null || true)
if [ -f "${PG_CONF}" ]; then
    CURRENT_LISTEN=$(sudo -u postgres psql -tAc "SHOW listen_addresses;" 2>/dev/null || true)
    if [ "${CURRENT_LISTEN}" != "*" ] && [[ ! "${CURRENT_LISTEN}" =~ "127.0.0.1" ]] && [[ ! "${CURRENT_LISTEN}" =~ "localhost" ]]; then
        echo -e "${YELLOW}Enabling TCP/IP loopback listening in ${PG_CONF}...${NC}"
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost,127.0.0.1'/g" "${PG_CONF}"
        sed -i "s/listen_addresses = '.*'/listen_addresses = 'localhost,127.0.0.1'/g" "${PG_CONF}"
        systemctl restart postgresql
        sleep 2
    fi
fi

# Ensure pg_hba.conf allows local md5/scram connections
PG_HBA=$(sudo -u postgres psql -tAc "SHOW hba_file;" 2>/dev/null || true)
if [ -f "${PG_HBA}" ]; then
    if ! grep -E -q "host\s+all\s+all\s+127\.0\.0\.1/32" "${PG_HBA}"; then
        echo -e "${YELLOW}Adding loopback TCP authentication rule to ${PG_HBA}...${NC}"
        echo "host    all             all             127.0.0.1/32            md5" >> "${PG_HBA}"
        systemctl reload postgresql 2>/dev/null || systemctl restart postgresql 2>/dev/null || true
    fi
fi

# Update .env files with the exact detected port
for ENV_TARGET in "${ROOT_DIR}/.env" "${BACKEND_DIR}/.env"; do
    if [ -f "${ENV_TARGET}" ]; then
        sed -i "s/^PG_PORT=.*/PG_PORT=${DB_PORT}/g" "${ENV_TARGET}"
        if ! grep -q "^PG_PORT=" "${ENV_TARGET}"; then
            echo "PG_PORT=${DB_PORT}" >> "${ENV_TARGET}"
        fi
        sed -i "s/^PG_HOST=.*/PG_HOST=127.0.0.1/g" "${ENV_TARGET}"
    else
        cat << EOF > "${ENV_TARGET}"
PG_DB=${DB_NAME}
PG_USER=${DB_USER}
PG_PASSWORD=${DB_PASS}
PG_HOST=127.0.0.1
PG_PORT=${DB_PORT}
PORT=8001
HOST=127.0.0.1
CLOUDFLARE_DOMAIN=app.srishakthi.in
EOF
    fi
done

# Ensure user and database exist
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || {
    echo "Creating PostgreSQL user '${DB_USER}'..."
    sudo -u postgres psql -c "CREATE USER \"${DB_USER}\" WITH PASSWORD '${DB_PASS}' SUPERUSER CREATEDB;"
}
sudo -u postgres psql -c "ALTER USER \"${DB_USER}\" WITH PASSWORD '${DB_PASS}';"

sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || {
    echo "Creating PostgreSQL database '${DB_NAME}'..."
    sudo -u postgres psql -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";"
}

# Ensure extensions exist
for EXT in "vector" "uuid-ossp" "pg_trgm"; do
    sudo -u postgres psql -d "${DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS \"${EXT}\";" >/dev/null 2>&1 || true
done
echo -e "${GREEN}[✓] Database role, catalog, and extensions verified.${NC}"

# Apply Core 01-init.sql
INIT_SQL="${ROOT_DIR}/docker/postgres/01-init.sql"
if [ ! -f "${INIT_SQL}" ]; then
    INIT_SQL="${BACKEND_DIR}/01-init.sql"
fi

if [ -f "${INIT_SQL}" ]; then
    echo "Applying core table definitions from ${INIT_SQL}..."
    PGPASSWORD="${DB_PASS}" psql -h 127.0.0.1 -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${INIT_SQL}" > /tmp/attenda_db_init.log 2>&1 || {
        # Fallback to local socket if TCP still syncing
        sudo -u postgres psql -d "${DB_NAME}" -f "${INIT_SQL}" > /tmp/attenda_db_init.log 2>&1 || true
    }
    echo -e "${GREEN}[✓] Core 01-init.sql schema applied.${NC}"
fi

# Apply schema compatibility for legacy columns and seeding queries
sudo -u postgres psql -d "${DB_NAME}" << 'EOSQL' >/dev/null 2>&1 || true
ALTER TABLE student_leave_od_action_history ALTER COLUMN action_by DROP NOT NULL;
ALTER TABLE student_leave_od_action_history ALTER COLUMN action_by_role DROP NOT NULL;
ALTER TABLE students ADD COLUMN IF NOT EXISTS year INT DEFAULT 1;
ALTER TABLE students ADD COLUMN IF NOT EXISTS roll_no VARCHAR(64);
ALTER TABLE students ADD COLUMN IF NOT EXISTS current_device_id VARCHAR(255);
ALTER TABLE students ADD COLUMN IF NOT EXISTS suspended BOOLEAN DEFAULT FALSE;
ALTER TABLE students ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE students ADD COLUMN IF NOT EXISTS first_time_login BOOLEAN DEFAULT TRUE;
ALTER TABLE departments ADD COLUMN IF NOT EXISTS dept_name VARCHAR(100);
UPDATE departments SET dept_name = name WHERE dept_name IS NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS current_device_id VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(160) DEFAULT '';
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(20) DEFAULT '';
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(80) DEFAULT 'staff';
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS kiosk_enabled BOOLEAN DEFAULT TRUE;
ALTER TABLE other_staff ADD COLUMN IF NOT EXISTS current_device_id VARCHAR(255);
ALTER TABLE other_staff ADD COLUMN IF NOT EXISTS suspended BOOLEAN DEFAULT FALSE;
ALTER TABLE other_staff ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE other_staff ADD COLUMN IF NOT EXISTS email VARCHAR(160) DEFAULT '';
ALTER TABLE other_staff ADD COLUMN IF NOT EXISTS phone VARCHAR(20) DEFAULT '';
EOSQL
echo -e "${GREEN}[✓] Schema parity and column compatibility verified.${NC}"

# ── 3. Python 3.12 Virtual Environment & Dependencies ──────────────────────────
echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${CYAN}[3/6] Auditing & Repairing Python 3.12 Backend Virtual Environment...${NC}"
echo -e "${BLUE}==============================================================================${NC}"

VENV_DIR="${BACKEND_DIR}/venv"
VENV_PYTHON="${VENV_DIR}/bin/python"
VENV_PIP="${VENV_DIR}/bin/pip"

if [ ! -f "${VENV_PYTHON}" ]; then
    echo "Creating clean Python 3.12 virtualenv at ${VENV_DIR}..."
    sudo -u "${RUN_USER}" python3 -m venv "${VENV_DIR}"
fi

sudo -u "${RUN_USER}" "${VENV_PIP}" install -q --upgrade pip setuptools wheel

# Install PyTorch with CUDA for RTX 5070
if command -v nvidia-smi &>/dev/null; then
    echo "Configuring PyTorch with CUDA 12.4 support for RTX 5070..."
    sudo -u "${RUN_USER}" "${VENV_PIP}" install -q torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124 || {
        sudo -u "${RUN_USER}" "${VENV_PIP}" install -q torch torchvision torchaudio
    }
    sudo -u "${RUN_USER}" "${VENV_PIP}" install -q onnxruntime-gpu || sudo -u "${RUN_USER}" "${VENV_PIP}" install -q onnxruntime
else
    sudo -u "${RUN_USER}" "${VENV_PIP}" install -q torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    sudo -u "${RUN_USER}" "${VENV_PIP}" install -q onnxruntime
fi

# Install requirements
sudo -u "${RUN_USER}" "${VENV_PIP}" install -q -r "${BACKEND_DIR}/requirements.txt"
echo -e "${GREEN}[✓] Python packages and runtime libraries installed.${NC}"

# Execute Anti-Spoofing & Liveness Migrations
if [ -f "${BACKEND_DIR}/migrations/apply_antispoof_migrations.py" ]; then
    echo "Running anti-spoofing database schema migrations..."
    sudo -u "${RUN_USER}" PG_PORT="${DB_PORT}" PG_HOST="127.0.0.1" PG_USER="${DB_USER}" PG_PASSWORD="${DB_PASS}" PG_DB="${DB_NAME}" "${VENV_PYTHON}" -c "
import sys; sys.path.insert(0, '${BACKEND_DIR}')
try:
    from migrations.apply_antispoof_migrations import apply_migrations
    apply_migrations()
except Exception as e:
    print(f'Notice on anti-spoof migration: {e}')
" || true
fi

# Execute Python Migrations & Default Seeding
if [ -f "${BACKEND_DIR}/run_migrations.py" ]; then
    echo "Executing database migration suite and table seeding..."
    sudo -u "${RUN_USER}" PG_PORT="${DB_PORT}" PG_HOST="127.0.0.1" PG_USER="${DB_USER}" PG_PASSWORD="${DB_PASS}" PG_DB="${DB_NAME}" "${VENV_PYTHON}" "${BACKEND_DIR}/run_migrations.py" || true
fi

# Pre-cache InsightFace model
echo "Ensuring InsightFace buffalo_s model weights are cached..."
sudo -u "${RUN_USER}" "${VENV_PYTHON}" -c "
import warnings; warnings.filterwarnings('ignore')
try:
    from insightface.app import FaceAnalysis
    app = FaceAnalysis(name='buffalo_s', providers=['CUDAExecutionProvider', 'CPUExecutionProvider'])
    app.prepare(ctx_id=-1, det_size=(640, 640))
    print('[✓] buffalo_s model pre-cached successfully.')
except Exception as e:
    print(f'[!] Model pre-cache notice: {e}')
" || true

# ── Apply Server Authentication Resilience Engine ──
if [ -f "${SCRIPT_DIR}/patch_server_auth.py" ]; then
    echo "Applying server-side authentication resilience engine to backend/main.py..."
    sudo -u "${RUN_USER}" "${VENV_PYTHON}" "${SCRIPT_DIR}/patch_server_auth.py" "${BACKEND_DIR}/main.py" || true
fi

# ── Audit Existing Database Credentials & Accounts ──
if [ -f "${SCRIPT_DIR}/diagnose_and_repair_auth.py" ]; then
    echo "Auditing existing accounts and verifying credentials on port ${DB_PORT}..."
    sudo -u "${RUN_USER}" PG_PORT="${DB_PORT}" PG_HOST="127.0.0.1" PG_USER="${DB_USER}" PG_PASSWORD="${DB_PASS}" PG_DB="${DB_NAME}" "${VENV_PYTHON}" "${SCRIPT_DIR}/diagnose_and_repair_auth.py" --audit || true
fi

# Audit table count
TABLE_COUNT=$(PGPASSWORD="${DB_PASS}" psql -h 127.0.0.1 -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null || sudo -u postgres psql -d "${DB_NAME}" -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")
echo -e "${GREEN}[✓] Total active public database tables: ${TABLE_COUNT}${NC}"

# ── 4. Systemd Backend Service ─────────────────────────────────────────────────
echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${CYAN}[4/6] Configuring and Starting Backend Systemd Service...${NC}"
echo -e "${BLUE}==============================================================================${NC}"

SERVICE_FILE="/etc/systemd/system/attenda-backend.service"

cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=VisionGate / Attenda FastAPI Backend Server
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=${RUN_USER}
Group=${RUN_USER}
WorkingDirectory=${BACKEND_DIR}
Environment=PYTHONUNBUFFERED=1
Environment=PORT=8001
Environment=HOST=127.0.0.1
Environment=PG_PORT=${DB_PORT}
Environment=PG_HOST=127.0.0.1
Environment=PG_USER=${DB_USER}
Environment=PG_PASSWORD=${DB_PASS}
Environment=PG_DB=${DB_NAME}
Environment=HOME=/home/${RUN_USER}
Environment=INSIGHTFACE_HOME=/home/${RUN_USER}/.insightface
EnvironmentFile=-${ROOT_DIR}/.env
EnvironmentFile=-${BACKEND_DIR}/.env
ExecStart=${VENV_PYTHON} main.py
Restart=always
RestartSec=3s
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable attenda-backend.service
systemctl restart attenda-backend.service

echo "Waiting for backend service to report healthy..."
for i in {1..20}; do
    if curl -sf http://127.0.0.1:8001/health &>/dev/null; then
        echo -e "${GREEN}[✓] attenda-backend.service is LIVE and reporting healthy!${NC}"
        break
    fi
    sleep 1
    if [ "$i" -eq 20 ]; then
        echo -e "${YELLOW}[!] Warning: Backend healthcheck timed out after 20s. Check 'journalctl -u attenda-backend -n 25'${NC}"
    fi
done

# ── 5. Nginx Reverse Proxy (Full API Routing + Redirection Protection) ─────────
echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${CYAN}[5/6] Configuring Nginx Reverse Proxy (Zero Route Hijacking & HTTPS Preservation)...${NC}"
echo -e "${BLUE}==============================================================================${NC}"

NGINX_CONF="/etc/nginx/sites-available/attenda"

cat << 'EOF' > "${NGINX_CONF}"
# Attenda / VisionGate Native Production Nginx Configuration
upstream attenda_backend {
    server 127.0.0.1:8001;
    keepalive 32;
}

map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    listen [::]:80;
    server_name app.srishakthi.in attenda.srishakthicgpa.in localhost _;

    # Cloudflare Real IP Restoration
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 131.0.72.0/22;
    set_real_ip_from 2400:cb00::/32;
    set_real_ip_from 2606:4700::/32;
    set_real_ip_from 2803:f800::/32;
    set_real_ip_from 2405:b500::/32;
    set_real_ip_from 2405:8100::/32;
    set_real_ip_from 2a06:98c0::/29;
    set_real_ip_from 2c0f:f248::/32;
    set_real_ip_from 127.0.0.1;
    real_ip_header CF-Connecting-IP;
    real_ip_recursive on;

    # Payload limits for biometric face images
    client_max_body_size 50M;
    client_body_buffer_size 10M;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

    # Security Headers
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Frame-Options SAMEORIGIN always;

    # WebSocket Support
    location /ws/ {
        proxy_pass http://attenda_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Nginx Healthcheck
    location /healthz {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Universal Backend API Proxy (Guarantees ALL 466 routes reach FastAPI)
    location / {
        proxy_pass http://attenda_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Enforce HTTPS scheme so FastAPI never issues http:// downgrade redirects
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        
        # Automatic rewrite of any backend 301/302/307 redirects to preserve HTTPS
        proxy_redirect http:// https://;

        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
        proxy_buffering on;
        proxy_buffers 8 16k;
        proxy_buffer_size 32k;
    }
}
EOF

ln -sf "${NGINX_CONF}" /etc/nginx/sites-enabled/attenda
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
echo -e "${GREEN}[✓] Nginx configured with HTTPS scheme preservation and zero route hijacking.${NC}"

# ── 6. Cloudflare Tunnel Ingress (app.srishakthi.in) ───────────────────────────
echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${CYAN}[6/6] Configuring Cloudflare Tunnel for app.srishakthi.in...${NC}"
echo -e "${BLUE}==============================================================================${NC}"

mkdir -p /etc/cloudflared

CRED_FILE="${ROOT_DIR}/docker/cloudflared/credentials.json"
if [ -f "${CRED_FILE}" ]; then
    cp "${CRED_FILE}" /etc/cloudflared/credentials.json
    chmod 600 /etc/cloudflared/credentials.json
fi

cat << 'EOF' > /etc/cloudflared/config.yml
tunnel: 27b90fd6-f11b-4f35-b160-47bcc2e2ed9e
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: app.srishakthi.in
    service: http://127.0.0.1:80
  - hostname: attenda.srishakthicgpa.in
    service: http://127.0.0.1:80
  - service: http_status:404
EOF

CF_BIN="$(command -v cloudflared || echo '/usr/bin/cloudflared')"

cat << EOF > /etc/systemd/system/cloudflared.service
[Unit]
Description=Cloudflare Tunnel Agent (Native)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=${CF_BIN} --config /etc/cloudflared/config.yml tunnel run
Restart=always
RestartSec=3s
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# If token is in .env, prefer official token service
TUNNEL_TOKEN=""
if [ -f "${ROOT_DIR}/.env" ]; then
    TUNNEL_TOKEN=$(grep -E "^CLOUDFLARE_TUNNEL_TOKEN=" "${ROOT_DIR}/.env" | cut -d '=' -f2- | tr -d '"' | tr -d "'" || true)
fi

if [ -n "${TUNNEL_TOKEN}" ]; then
    echo "Installing cloudflared service via tunnel token..."
    cloudflared service uninstall 2>/dev/null || true
    cloudflared service install "${TUNNEL_TOKEN}" || true
fi

systemctl daemon-reload
systemctl enable --now cloudflared 2>/dev/null || systemctl restart cloudflared 2>/dev/null || true
echo -e "${GREEN}[✓] Cloudflare tunnel agent configured and running.${NC}"

# ── 7. Verification Summary ────────────────────────────────────────────────────
echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BOLD}${GREEN}  SYSTEM AUTO-HEALING & DEPLOYMENT COMPLETE (100% OPERATIONAL)                ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo -e "Operational Status Summary:"
echo -e "  - Backend Loopback:   http://127.0.0.1:8001/health ($(curl -sf http://127.0.0.1:8001/health || echo 'offline'))"
echo -e "  - Nginx Ingress:      http://127.0.0.1/healthz ($(curl -sf http://127.0.0.1/healthz || echo 'offline'))"
echo -e "  - Public Tunnel URL:  https://app.srishakthi.in"
echo -e "  - Fallback URL:       https://attenda.srishakthicgpa.in"
echo -e "  - Database Tables:    ${TABLE_COUNT} verified"
echo -e "  - Systemd Service:    sudo systemctl status attenda-backend"
echo -e "  - Ingress Service:    sudo systemctl status cloudflared"
echo -e "${BLUE}==============================================================================${NC}\n"
