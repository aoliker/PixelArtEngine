# ScarForge — ComfyUI Pixel Art Pipeline

Generate 32×32 dark fantasy pixel art tiles for ScarForge using Stable Diffusion XL with the pixel-art-xl LoRA.

## Requirements

- **Mac with Apple Silicon** (M1/M2/M3/M4) — uses MPS backend
- **Python 3.10+**
- **~10 GB disk space** (SDXL model is ~6.9 GB)
- **16 GB+ RAM recommended** for SDXL generation

## Quick Start

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
cd comfyui-setup
python scripts/generate-test-image.py

# Custom prompt:
python scripts/generate-test-image.py --prompt-text "pixel, pixel art, top-down dark fantasy blacksmith, ..."

# Specific seed for reproducibility:
python scripts/generate-test-image.py --seed 12345
```

## What Gets Installed

| Component | Source | Location |
|-----------|--------|----------|
| ComfyUI | github.com/comfyanonymous/ComfyUI | `~/ComfyUI/` |
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
detailed shading, no anti-aliasing, clean pixel edges
```

### Negative Prompt (always use)

```
blurry, smooth gradients, anti-aliasing, 3d render, realistic,
photographic, modern, futuristic, sci-fi, bright colors, neon,
watermark, text, signature, jpeg artifacts, low quality, deformed,
ugly, oversaturated, bloom, glow effects
```

## Troubleshooting

### "MPS not available"
Ensure you're on macOS 12.3+ and using the arm64 Python build (not x86 via Rosetta):
```bash
python3 -c "import platform; print(platform.machine())"
# Should print: arm64
```

### Out of memory
Use `--force-fp16` flag when starting ComfyUI. If still OOM, reduce resolution to 768×768 in the workflow.

### Slow generation
First run downloads and compiles MPS kernels (~2-3 min). Subsequent runs should take 30-90s per image on M1/M2.

### PixelArt-Detector node not found
Restart ComfyUI after installing the plugin. Check `custom_nodes/ComfyUI-PixelArt-Detector/` exists.

## Directory Structure

```
comfyui-setup/
├── README.md                  ← You are here
├── scripts/
│   ├── setup-comfyui-mac.sh   ← One-click installer
│   └── generate-test-image.py ← API-based generator
└── workflows/
    ├── scarforge-pixelart-building.json  ← Main workflow (load in ComfyUI UI)
    └── scarforge-batch-tiles.json        ← Prompt templates for all building types
```
