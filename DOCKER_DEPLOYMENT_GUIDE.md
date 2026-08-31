# Production Docker Deployment Guide for Attenda / VisionGate

This guide details the deployment of the VisionGate / Attenda facial attendance and staff management system on Ubuntu 24.04.4 LTS (Noble) with NVIDIA GeForce RTX 5070 (Blackwell architecture) and CUDA 13.x.

---

## 1. System Specifications & Topology

- **Host Machine**: Alienware Aurora ACT1250 / x86_64
- **Host Operating System**: Ubuntu 24.04.4 LTS (Linux 7.0 Kernel)
- **CPU**: Intel Core Ultra 9 285K (24 cores)
- **Host Memory**: 32 GB RAM
- **Host Storage**: SK hynix NVMe (953 GB)
- **GPU**: NVIDIA GeForce RTX 5070 (12 GB VRAM, Blackwell `sm_120`, Driver 595.84, CUDA 13.2)
- **Local Network**: Ethernet `192.168.76.12` / Wi-Fi `10.20.25.66`

### Container Architecture

| Service | Container Name | Image / Base | Internal Port | Host Port | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Database** | `attenda-postgres` | `pgvector/pgvector:pg16` | `5432` | `5432` | PostgreSQL 16 with pgvector extension & persistent storage |
| **Backend** | `attenda-backend` | `nvidia/cuda:12.8.0-cudnn-runtime-ubuntu24.04` | `8001` | `8001` | FastAPI API server with InsightFace, PyTorch CUDA 13, and ONNX Runtime GPU |
| **Reverse Proxy** | `attenda-nginx` | `nginx:1.27-alpine` | `80` | `80` | Reverse proxy, WebSocket routing (`/ws/`), compression, and upload buffering |

---

## 2. Prerequisites on Target Host (Ubuntu 24.04)

Ensure standard Docker and NVIDIA Container Toolkit are installed:

```bash
# 1. Install Docker Engine
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 2. Add current user to docker group (if not already added)
sudo usermod -aG docker $USER

# 3. Configure NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

---

## 3. Quickstart Deployment

Execute the automated deployment script directly from the project root:

```bash
chmod +x scripts/*.sh backend/entrypoint.sh
bash scripts/deploy.sh
```

The script automatically:
1. Validates host NVIDIA drivers and Docker runtime.
2. Generates `.env` from `.env.example` if not present.
3. Builds the CUDA 13.0 + ONNX Runtime GPU backend image and pre-caches the `buffalo_s` model.
4. Starts the multi-container stack with health checks.
5. Displays the active service URLs and IP bindings.

---

## 4. Verification & Diagnostics

### Run GPU Diagnostics
To verify that PyTorch and ONNX Runtime are utilizing the RTX 5070 GPU inside the container:

```bash
bash scripts/verify_gpu.sh
```

Expected diagnostic output:
- `PyTorch CUDA available: True`
- `Device Name: NVIDIA GeForce RTX 5070`
- `ONNX Providers:` includes `CUDAExecutionProvider`

### Test HTTP Endpoints
```bash
# Direct API health check
curl http://localhost:8001/

# Nginx reverse proxy health check
curl http://localhost:80/healthz

# Interactive Swagger Documentation
# Open in browser: http://192.168.76.12:8001/docs
```

---

## 5. Client Application Configuration (Flutter App / Mobile / Kiosk)

In the Flutter application configuration (`college_ip_config.dart`):

```dart
// Point to the Ubuntu 24.04 server IP address
const String customServerURL = "http://192.168.76.12:8001";
```

---

## 6. Daily Management & Operational Commands

### View Live Logs
```bash
# Stream backend logs
docker compose logs -f backend

# Stream database logs
docker compose logs -f postgres

# Stream all container logs
docker compose logs -f
```

### Stop and Restart Services
```bash
# Stop all services
docker compose down

# Start services in background
docker compose up -d

# Rebuild and restart after code changes
docker compose up -d --build
```

### Database Backup & Restore
```bash
# Create an instant compressed database backup
bash scripts/backup_db.sh

# Restore from a backup archive
bash scripts/restore_db.sh ./backups/attenda_db_backup_YYYYMMDD_HHMMSS.sql.gz
```

---

## 7. Persistent Data & Volumes

The Docker stack defines three persistent volumes:
- `attenda_postgres_data`: Houses all PostgreSQL tables, relations, indexes, and vector embeddings.
- `attenda_storage`: Houses user avatars, export spreadsheets, and report attachments.
- `attenda_insightface_models`: Houses cached InsightFace models (`buffalo_s`) for fast restarts.
