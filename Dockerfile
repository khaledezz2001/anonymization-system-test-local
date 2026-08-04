FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV HF_HOME=/models
ENV HF_HUB_ENABLE_HF_TRANSFER=0
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

# Remove pre-installed torchvision/torchaudio — not needed for text-only LLM inference
RUN pip uninstall -y torchvision torchaudio 2>/dev/null || true

# Upgrade PyTorch to 2.6 with CUDA 12.4 wheels (vLLM 0.8.5 needs PyTorch 2.6+)
RUN pip install --no-cache-dir torch==2.6.0 --index-url https://download.pytorch.org/whl/cu124

# Install vLLM + Python deps (let vLLM manage its own transformers version)
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

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

# Patch tokenizer config: convert extra_special_tokens from list to dict
# (vLLM's bundled transformers crashes if extra_special_tokens is a list)
RUN python3 -u <<'PATCH'
import json, os

config_path = "/app/models/qwen3-4b-cuad-entities-v2/tokenizer_config.json"
if os.path.exists(config_path):
    with open(config_path, "r") as f:
        config = json.load(f)

    if "extra_special_tokens" in config and isinstance(config["extra_special_tokens"], list):
        print(f"Patching extra_special_tokens: list of {len(config['extra_special_tokens'])} items -> empty dict", flush=True)
        config["extra_special_tokens"] = {}
        with open(config_path, "w") as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        print("Tokenizer config patched successfully", flush=True)
    else:
        print("No patching needed", flush=True)
else:
    print(f"WARNING: {config_path} not found!", flush=True)
PATCH

WORKDIR /app
COPY handler.py /app/handler.py

ENTRYPOINT ["python3"]
CMD ["-u", "handler.py"]