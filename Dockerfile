FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV HF_HOME=/models
ENV HF_HUB_ENABLE_HF_TRANSFER=0
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

# Remove pre-installed torchvision/torchaudio — not needed for text-only LLM inference
RUN pip uninstall -y torchvision torchaudio 2>/dev/null || true

# Install vLLM + Python deps (PyTorch 2.4 + CUDA 12.4 from base image)
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir --upgrade -r /requirements.txt

# ===============================
# DOWNLOAD qwen3-4b-cuad-entities-v2
# ===============================
RUN python3 -u <<'EOF'
from huggingface_hub import snapshot_download

print("Downloading khaled12331/qwen3-4b-cuad-entities-v2...", flush=True)

snapshot_download(
    repo_id="khaled12331/qwen3-4b-cuad-entities-v2",
    local_dir="/app/models/qwen3-4b-cuad-entities-v2",
    local_dir_use_symlinks=False,
    resume_download=True
)

print("qwen3-4b-cuad-entities-v2 download complete", flush=True)
EOF

WORKDIR /app
COPY handler.py /app/handler.py

ENTRYPOINT ["python3"]
CMD ["-u", "handler.py"]