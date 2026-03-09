"""
scarforge_batch.py — Queue all ScarForge asset prompts to ComfyUI API.

Usage (run on Windows machine where ComfyUI is running):
    python scarforge_batch.py                          # all batch files
    python scarforge_batch.py tiles                    # just tiles
    python scarforge_batch.py buildings props           # buildings + props
    python scarforge_batch.py --host 192.168.1.50      # remote ComfyUI

Reads prompts from workflows/scarforge-batch-*.json and queues each one
to ComfyUI's /prompt API endpoint with the correct API-format workflow.
"""

import argparse
import json
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

COMFYUI_DEFAULT = "http://127.0.0.1:8188"

# ComfyUI API-format workflow template.
# Node IDs are strings. Inputs reference other nodes as ["node_id", output_index].
WORKFLOW_API = {
    "1": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {
            "ckpt_name": "sd_xl_base_1.0.safetensors"
        }
    },
    "2": {
        "class_type": "LoraLoader",
        "inputs": {
            "model": ["1", 0],
            "clip": ["1", 1],
            "lora_name": "pixel-art-xl.safetensors",
            "strength_model": 0.85,
            "strength_clip": 0.85
        }
    },
    "3": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": ["2", 1],
            "text": "POSITIVE_PROMPT_HERE"
        }
    },
    "4": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "clip": ["2", 1],
            "text": "NEGATIVE_PROMPT_HERE"
        }
    },
    "5": {
        "class_type": "EmptyLatentImage",
        "inputs": {
            "width": 1024,
            "height": 1024,
            "batch_size": 1
        }
    },
    "6": {
        "class_type": "KSampler",
        "inputs": {
            "model": ["2", 0],
            "positive": ["3", 0],
            "negative": ["4", 0],
            "latent_image": ["5", 0],
            "seed": 42,
            "control_after_generate": "fixed",
            "steps": 30,
            "cfg": 7.5,
            "sampler_name": "euler_ancestral",
            "scheduler": "normal",
            "denoise": 1.0
        }
    },
    "7": {
        "class_type": "VAEDecode",
        "inputs": {
            "samples": ["6", 0],
            "vae": ["1", 2]
        }
    },
    "8": {
        "class_type": "ImageScale",
        "inputs": {
            "image": ["7", 0],
            "upscale_method": "nearest-exact",
            "width": 32,
            "height": 32,
            "crop": "disabled"
        }
    },
    "9": {
        "class_type": "ImageScale",
        "inputs": {
            "image": ["8", 0],
            "upscale_method": "nearest-exact",
            "width": 256,
            "height": 256,
            "crop": "disabled"
        }
    },
    "10": {
        "class_type": "SaveImage",
        "inputs": {
            "images": ["7", 0],
            "filename_prefix": "ScarForge/full/ASSET_NAME"
        }
    },
    "11": {
        "class_type": "SaveImage",
        "inputs": {
            "images": ["8", 0],
            "filename_prefix": "ScarForge/tiles/ASSET_NAME"
        }
    },
    "12": {
        "class_type": "SaveImage",
        "inputs": {
            "images": ["9", 0],
            "filename_prefix": "ScarForge/preview/ASSET_NAME"
        }
    }
}


def build_prompt(positive: str, negative: str, asset_name: str, seed: int = 42) -> dict:
    """Build a complete API prompt payload for one asset."""
    workflow = json.loads(json.dumps(WORKFLOW_API))
    workflow["3"]["inputs"]["text"] = positive
    workflow["4"]["inputs"]["text"] = negative
    workflow["6"]["inputs"]["seed"] = seed
    workflow["10"]["inputs"]["filename_prefix"] = f"ScarForge/full/{asset_name}"
    workflow["11"]["inputs"]["filename_prefix"] = f"ScarForge/tiles/{asset_name}"
    workflow["12"]["inputs"]["filename_prefix"] = f"ScarForge/preview/{asset_name}"
    return {"prompt": workflow}


def queue_prompt(payload: dict, server: str) -> dict:
    """Send a prompt to ComfyUI and return the response."""
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{server}/prompt",
        data=data,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def load_batch_file(path: Path) -> tuple[dict, str]:
    """Load a batch JSON file, return (prompts_dict, negative_prompt)."""
    with open(path) as f:
        data = json.load(f)
    return data["prompts"], data["negative"]


def main():
    parser = argparse.ArgumentParser(description="Queue ScarForge assets to ComfyUI")
    parser.add_argument("batches", nargs="*", default=["tiles", "buildings", "props"],
                        help="Which batch files to process: tiles, buildings, props (default: all)")
    parser.add_argument("--host", default=COMFYUI_DEFAULT,
                        help=f"ComfyUI server URL (default: {COMFYUI_DEFAULT})")
    parser.add_argument("--seed", type=int, default=42,
                        help="Base seed (incremented per asset, default: 42)")
    parser.add_argument("--delay", type=float, default=1.0,
                        help="Seconds between queue submissions (default: 1.0)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be queued without sending")
    args = parser.parse_args()

    # Find batch files relative to this script
    script_dir = Path(__file__).parent.parent / "workflows"
    if not script_dir.exists():
        script_dir = Path("workflows")

    batch_files = []
    for name in args.batches:
        path = script_dir / f"scarforge-batch-{name}.json"
        if not path.exists():
            print(f"ERROR: Batch file not found: {path}")
            sys.exit(1)
        batch_files.append(path)

    # Collect all assets
    assets = []
    for path in batch_files:
        prompts, negative = load_batch_file(path)
        for asset_name, positive in prompts.items():
            assets.append((asset_name, positive, negative))

    print(f"ScarForge Batch Generator")
    print(f"  Server:  {args.host}")
    print(f"  Assets:  {len(assets)} total from {len(batch_files)} batch file(s)")
    print(f"  Seed:    {args.seed}")
    print()

    # Queue each asset
    for i, (asset_name, positive, negative) in enumerate(assets):
        seed = args.seed + i
        payload = build_prompt(positive, negative, asset_name, seed)

        if args.dry_run:
            print(f"  [{i+1:3d}/{len(assets)}] {asset_name} (seed {seed}) — DRY RUN")
            continue

        try:
            result = queue_prompt(payload, args.host)
            prompt_id = result.get("prompt_id", "???")
            print(f"  [{i+1:3d}/{len(assets)}] {asset_name} (seed {seed}) — queued: {prompt_id}")
        except urllib.error.URLError as e:
            print(f"  [{i+1:3d}/{len(assets)}] {asset_name} — FAILED: {e}")
            print(f"  Is ComfyUI running at {args.host}?")
            sys.exit(1)

        if i < len(assets) - 1:
            time.sleep(args.delay)

    print()
    if args.dry_run:
        print(f"Dry run complete. {len(assets)} assets would be queued.")
    else:
        print(f"All {len(assets)} assets queued. Check ComfyUI queue for progress.")
        print(f"Output folders:")
        print(f"  32x32 tiles:  ComfyUI/output/ScarForge/tiles/")
        print(f"  Full res:     ComfyUI/output/ScarForge/full/")
        print(f"  256x256 prev: ComfyUI/output/ScarForge/preview/")


if __name__ == "__main__":
    main()
