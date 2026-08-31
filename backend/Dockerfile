# ==============================================================================
# VisionGate / Attenda - High Performance GPU Backend Container
# Target: Ubuntu 24.04 LTS | Intel Core Ultra 9 285K | NVIDIA RTX 5070 (sm_120)
# ==============================================================================

FROM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu24.04

# Prevent interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8 \
    PATH="/opt/venv/bin:$PATH" \
    INSIGHTFACE_HOME="/root/.insightface"

# Install system dependencies, Python 3.12, OpenCV/FFmpeg shared libraries, and networking utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgomp1 \
    ffmpeg \
    curl \
    netcat-openbsd \
    ca-certificates \
    wget \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create and activate Python virtual environment
RUN python3 -m venv /opt/venv

# Upgrade pip and packaging tools
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install core application requirements
WORKDIR /app
COPY requirements.txt /app/requirements.txt

# Install base dependencies (excluding torch and onnxruntime-gpu which need CUDA 13 wheels)
RUN grep -v "onnxruntime-gpu" requirements.txt > /tmp/requirements_base.txt && \
    pip install --no-cache-dir -r /tmp/requirements_base.txt && \
    rm /tmp/requirements_base.txt

# Install PyTorch built against CUDA 13.0 (for Blackwell sm_120 support)
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130

# Install ONNX Runtime GPU (CUDA 13 build)
RUN pip install --no-cache-dir coloredlogs flatbuffers packaging protobuf sympy && \
    pip install --no-cache-dir --pre --index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/ort-cuda-13-nightly/pypi/simple/ onnxruntime-gpu

# Ensure InsightFace is installed and pre-cache buffalo_s model files into image
RUN pip install --no-cache-dir insightface==0.7.3 && \
    python3 -c "import insightface; from insightface.app import FaceAnalysis; app = FaceAnalysis(name='buffalo_s', providers=['CPUExecutionProvider']); app.prepare(ctx_id=-1, det_size=(640, 640)); print('InsightFace buffalo_s model pre-cached successfully.')"

# Copy application source code
COPY . /app

# Ensure debug_images and storage directories exist
RUN mkdir -p /app/debug_images /app/storage /root/.insightface/models

# Setup entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose backend port
EXPOSE 8001

# Container healthcheck
HEALTHCHECK --interval=20s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8001/ || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
