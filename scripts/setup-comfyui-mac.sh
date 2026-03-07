#!/usr/bin/env bash
# ============================================================================
# ComfyUI Setup for Mac (Apple Silicon / MPS Backend)
# Project: ScarForge — Dark Fantasy Dungeon Crawler
# ============================================================================
set -euo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-$HOME/ComfyUI}"
PYTHON="${PYTHON:-python3}"

echo "============================================"
echo " ScarForge — ComfyUI Pixel Art Setup"
echo " Target: Mac with Apple Silicon (MPS)"
echo "============================================"
echo ""

# -------------------------------------------------------------------
# 1. Check prerequisites
# -------------------------------------------------------------------
echo "[1/7] Checking prerequisites..."

# Python version check
PY_VERSION=$($PYTHON --version 2>&1 | awk '{print $2}')
PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)

if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
    echo "ERROR: Python 3.10+ required. Found: $PY_VERSION"
    echo "Install via: brew install python@3.12"
    exit 1
fi
echo "  Python $PY_VERSION ✓"

# Check for git
if ! command -v git &> /dev/null; then
    echo "ERROR: git is required. Install via: brew install git"
    exit 1
fi
echo "  git ✓"

# Check for Apple Silicon
if [ "$(uname -m)" = "arm64" ]; then
    echo "  Apple Silicon detected ✓"
else
    echo "  WARNING: Not running on arm64. MPS backend may not be available."
fi

# -------------------------------------------------------------------
# 2. Clone ComfyUI
# -------------------------------------------------------------------
echo ""
echo "[2/7] Setting up ComfyUI at $COMFYUI_DIR..."

if [ -d "$COMFYUI_DIR" ]; then
    echo "  ComfyUI directory exists, pulling latest..."
    cd "$COMFYUI_DIR"
    git pull
else
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
    cd "$COMFYUI_DIR"
fi

# -------------------------------------------------------------------
# 3. Create venv and install dependencies
# -------------------------------------------------------------------
echo ""
echo "[3/7] Creating virtual environment and installing dependencies..."

if [ ! -d "$COMFYUI_DIR/venv" ]; then
    $PYTHON -m venv venv
fi

source venv/bin/activate

# Install PyTorch with MPS support (nightly has best MPS support)
pip install --upgrade pip
pip install torch torchvision torchaudio

# Install ComfyUI requirements
pip install -r requirements.txt

# Verify MPS availability
$PYTHON -c "
import torch
if torch.backends.mps.is_available():
    print('  MPS backend available ✓')
else:
    print('  WARNING: MPS not available. Will fall back to CPU.')
    if not torch.backends.mps.is_built():
        print('  PyTorch was not built with MPS support.')
"

# -------------------------------------------------------------------
# 4. Download SDXL base model
# -------------------------------------------------------------------
echo ""
echo "[4/7] Downloading SDXL base model..."

MODELS_DIR="$COMFYUI_DIR/models/checkpoints"
SDXL_MODEL="$MODELS_DIR/sd_xl_base_1.0.safetensors"

if [ -f "$SDXL_MODEL" ]; then
    echo "  SDXL base model already exists ✓"
else
    echo "  Downloading stabilityai/stable-diffusion-xl-base-1.0..."
    echo "  (This is ~6.9 GB, may take a while)"

    # Try huggingface-cli first, fall back to wget
    if command -v huggingface-cli &> /dev/null; then
        huggingface-cli download stabilityai/stable-diffusion-xl-base-1.0 \
            sd_xl_base_1.0.safetensors \
            --local-dir "$MODELS_DIR" \
            --local-dir-use-symlinks False
    else
        pip install huggingface_hub
        $PYTHON -c "
from huggingface_hub import hf_hub_download
hf_hub_download(
    repo_id='stabilityai/stable-diffusion-xl-base-1.0',
    filename='sd_xl_base_1.0.safetensors',
    local_dir='$MODELS_DIR',
    local_dir_use_symlinks=False
)
"
    fi
    echo "  SDXL base model downloaded ✓"
fi

# -------------------------------------------------------------------
# 5. Download pixel-art-xl LoRA
# -------------------------------------------------------------------
echo ""
echo "[5/7] Downloading pixel-art-xl LoRA..."

LORA_DIR="$COMFYUI_DIR/models/loras"
mkdir -p "$LORA_DIR"
LORA_FILE="$LORA_DIR/pixel-art-xl.safetensors"

if [ -f "$LORA_FILE" ]; then
    echo "  pixel-art-xl LoRA already exists ✓"
else
    echo "  Downloading nerijs/pixel-art-xl..."
    $PYTHON -c "
from huggingface_hub import hf_hub_download
hf_hub_download(
    repo_id='nerijs/pixel-art-xl',
    filename='pixel-art-xl.safetensors',
    local_dir='$LORA_DIR',
    local_dir_use_symlinks=False
)
"
    echo "  pixel-art-xl LoRA downloaded ✓"
fi

# -------------------------------------------------------------------
# 6. Install PixelArt-Detector custom node
# -------------------------------------------------------------------
echo ""
echo "[6/7] Installing ComfyUI-PixelArt-Detector plugin..."

CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
PIXELART_DIR="$CUSTOM_NODES_DIR/ComfyUI-PixelArt-Detector"

if [ -d "$PIXELART_DIR" ]; then
    echo "  Plugin exists, pulling latest..."
    cd "$PIXELART_DIR"
    git pull
else
    cd "$CUSTOM_NODES_DIR"
    git clone https://github.com/dimtoneff/ComfyUI-PixelArt-Detector.git
fi

# Install plugin dependencies if any
if [ -f "$PIXELART_DIR/requirements.txt" ]; then
    pip install -r "$PIXELART_DIR/requirements.txt"
fi

cd "$COMFYUI_DIR"

# -------------------------------------------------------------------
# 7. Copy ScarForge workflows
# -------------------------------------------------------------------
echo ""
echo "[7/7] Setting up ScarForge workflows..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_SRC="$SCRIPT_DIR/../workflows"

if [ -d "$WORKFLOW_SRC" ]; then
    mkdir -p "$COMFYUI_DIR/user/default/workflows/ScarForge"
    cp "$WORKFLOW_SRC"/*.json "$COMFYUI_DIR/user/default/workflows/ScarForge/" 2>/dev/null || true
    echo "  Workflows copied ✓"
else
    echo "  No workflow directory found, skipping."
fi

# -------------------------------------------------------------------
# Done!
# -------------------------------------------------------------------
echo ""
echo "============================================"
echo " Setup Complete!"
echo "============================================"
echo ""
echo " To start ComfyUI:"
echo "   cd $COMFYUI_DIR"
echo "   source venv/bin/activate"
echo "   python main.py --force-fp16"
echo ""
echo " Then open http://127.0.0.1:8188 in your browser."
echo ""
echo " --force-fp16 is recommended for Apple Silicon to"
echo " reduce memory usage with the SDXL model."
echo ""
echo " Installed components:"
echo "   • SDXL Base 1.0 checkpoint"
echo "   • pixel-art-xl LoRA (trigger word: 'pixel')"
echo "   • ComfyUI-PixelArt-Detector node"
echo "   • ScarForge pixel art workflows"
echo ""
echo " Next: Load the ScarForge workflow from the"
echo " workflows menu and hit 'Queue Prompt'!"
echo "============================================"
