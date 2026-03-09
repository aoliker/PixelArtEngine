# ScarForge — ComfyUI Pixel Art Pipeline

Generate 32×32 dark fantasy pixel art tiles for ScarForge using Stable Diffusion XL with the pixel-art-xl LoRA.

## Requirements

### Windows (NVIDIA GPU)
- **NVIDIA GPU with 8GB+ VRAM** (e.g., RTX 3070) — uses CUDA backend
- **Python 3.10–3.12** (3.13+ not yet supported by PyTorch CUDA builds)
- **NVIDIA drivers + CUDA toolkit** installed
- **~10 GB disk space** (SDXL model is ~6.9 GB)

### Mac (Apple Silicon)
- **Mac with Apple Silicon** (M1/M2/M3/M4) — uses MPS backend
- **Python 3.10+**
- **~10 GB disk space** (SDXL model is ~6.9 GB)
- **16 GB+ RAM recommended** for SDXL generation

## Quick Start

### Windows (NVIDIA GPU)

```cmd
REM 1. Run the setup script (installs everything)
scripts\setup-comfyui-nvidia.bat

REM 2. Start ComfyUI with the launcher
scripts\start-comfyui-nvidia.bat

REM 3. Open http://127.0.0.1:8188 in your browser

REM 4. Load the ScarForge workflow:
REM    Menu → Load → ScarForge/scarforge-pixelart-building.json

REM 5. Click "Queue Prompt" to generate!
```

### Mac (Apple Silicon)

```bash
# 1. Run the setup script (installs everything)
./scripts/setup-comfyui-mac.sh

# 2. Start ComfyUI
cd ~/ComfyUI
source venv/bin/activate
python main.py --force-fp16

# 3. Open http://127.0.0.1:8188 in your browser

# 4. Load the ScarForge workflow:
#    Menu → Load → ScarForge/scarforge-pixelart-building.json

# 5. Click "Queue Prompt" to generate!
```

## Alternative: Generate via API

With ComfyUI running, use the Python script:

```bash
python scripts/generate-test-image.py

# Custom prompt:
python scripts/generate-test-image.py --prompt-text "pixel, pixel art, top-down dark fantasy blacksmith, ..."

# Specific seed for reproducibility:
python scripts/generate-test-image.py --seed 12345
```

## What Gets Installed

| Component | Source | Location |
|-----------|--------|----------|
| ComfyUI | github.com/comfyanonymous/ComfyUI | `~/ComfyUI/` (Mac) or `%USERPROFILE%\ComfyUI` (Windows) |
| SDXL Base 1.0 | stabilityai/stable-diffusion-xl-base-1.0 | `models/checkpoints/` |
| pixel-art-xl LoRA | nerijs/pixel-art-xl | `models/loras/` |
| PixelArt-Detector | github.com/dimtoneff/ComfyUI-PixelArt-Detector | `custom_nodes/` |

## Workflow Overview

```
SDXL Base → LoRA (pixel-art-xl, 0.85) → KSampler → VAE Decode
                                                        ↓
                                              ┌─────────┼─────────┐
                                              ↓         ↓         ↓
                                          Full 1024   32×32    256×256
                                          (reference)  (tile)  (preview)
```

**Pipeline:**
1. Load SDXL Base 1.0 checkpoint
2. Apply pixel-art-xl LoRA (strength 0.85) — trigger word: `pixel`
3. Generate at 1024×1024 (SDXL native resolution)
4. Downscale to 32×32 with **nearest-neighbor** (preserves pixel edges)
5. Upscale to 256×256 preview (nearest-neighbor, for visual inspection)

**Sampler settings:** Euler Ancestral, 30 steps, CFG 7.5

## ScarForge Prompt Templates

All prompts start with the LoRA trigger word `pixel` and include style anchors for consistent output.

See `workflows/scarforge-batch-tiles.json` for a full set of building prompts:
- Tavern, Blacksmith, Chapel, Market Stall
- Watchtower, Well, Graveyard, Dungeon Entrance

### Prompt Structure

```
pixel, pixel art, top-down view, dark fantasy [SUBJECT], [DETAILS],
gritty atmosphere, muted dark palette, 32x32 tile sprite, game asset,
detailed shading, clean pixel edges
```

### Negative Prompt (always use)

```
blurry, smooth gradients, anti-aliasing, 3d render, realistic,
photographic, modern, futuristic, sci-fi, bright colors, neon,
watermark, text, signature, jpeg artifacts, low quality, deformed,
ugly, oversaturated, bloom, glow effects
```

## Troubleshooting

### CUDA not available (Windows)
Verify NVIDIA drivers are installed and CUDA is accessible:
```cmd
nvidia-smi
python -c "import torch; print(torch.cuda.is_available())"
```
If `False`, reinstall PyTorch with CUDA support:
```cmd
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

### Out of memory (8GB VRAM)
The `--force-fp16` flag is required for 8GB VRAM GPUs like the RTX 3070. The launcher script includes this automatically. If still OOM, reduce resolution to 768×768 in the workflow.

### "MPS not available" (Mac)
Ensure you're on macOS 12.3+ and using the arm64 Python build (not x86 via Rosetta):
```bash
python3 -c "import platform; print(platform.machine())"
# Should print: arm64
```

### Slow generation
- **Windows (NVIDIA):** First run may compile CUDA kernels. RTX 3070 should generate in ~15-30s per image.
- **Mac (Apple Silicon):** First run downloads and compiles MPS kernels (~2-3 min). Subsequent runs should take 30-90s per image on M1/M2.

### PixelArt-Detector node not found
Restart ComfyUI after installing the plugin. Check `custom_nodes/ComfyUI-PixelArt-Detector/` exists.

## Directory Structure

```
PixelArtEngine/
├── README.md                      ← You are here
├── scripts/
│   ├── setup-comfyui-nvidia.bat   ← Windows/NVIDIA installer
│   ├── start-comfyui-nvidia.bat   ← Windows launcher (--force-fp16)
│   ├── setup-comfyui-mac.sh       ← Mac/Apple Silicon installer
│   └── generate-test-image.py     ← API-based generator
└── workflows/
    ├── scarforge-pixelart-building.json  ← Main workflow (load in ComfyUI UI)
    └── scarforge-batch-tiles.json        ← Prompt templates for all building types
```
