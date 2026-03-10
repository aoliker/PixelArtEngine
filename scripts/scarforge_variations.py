"""
scarforge_variations.py — Generate race/expression variations using cos-seed curves.

Uses a cosine function to create deterministic but varied seeds for each variant.
Knobs: amplitude, frequency, x_shift, and offset control the seed distribution.

Usage:
    python scarforge_variations.py elves                    # 5 elf variants
    python scarforge_variations.py elves --amplitude 15000  # wider variation
    python scarforge_variations.py elves --x-shift 1.5      # different family
    python scarforge_variations.py elves --dry-run           # preview seeds

Future: use the same curve for facial expressions per character.
"""

import argparse
import json
import math
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

COMFYUI_DEFAULT = "http://127.0.0.1:8188"

# Same API workflow template as scarforge_batch.py
WORKFLOW_API = {
    "1": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}
    },
    "2": {
        "class_type": "LoraLoader",
        "inputs": {
            "model": ["1", 0], "clip": ["1", 1],
            "lora_name": "pixel-art-xl.safetensors",
            "strength_model": 0.85, "strength_clip": 0.85
        }
    },
    "3": {
        "class_type": "CLIPTextEncode",
        "inputs": {"clip": ["2", 1], "text": ""}
    },
    "4": {
        "class_type": "CLIPTextEncode",
        "inputs": {"clip": ["2", 1], "text": ""}
    },
    "5": {
        "class_type": "EmptyLatentImage",
        "inputs": {"width": 1024, "height": 1024, "batch_size": 1}
    },
    "6": {
        "class_type": "KSampler",
        "inputs": {
            "model": ["2", 0], "positive": ["3", 0],
            "negative": ["4", 0], "latent_image": ["5", 0],
            "seed": 42, "control_after_generate": "fixed",
            "steps": 30, "cfg": 7.5,
            "sampler_name": "euler_ancestral", "scheduler": "normal",
            "denoise": 1.0
        }
    },
    "7": {
        "class_type": "VAEDecode",
        "inputs": {"samples": ["6", 0], "vae": ["1", 2]}
    },
    "8": {
        "class_type": "ImageScale",
        "inputs": {
            "image": ["7", 0], "upscale_method": "nearest-exact",
            "width": 32, "height": 32, "crop": "disabled"
        }
    },
    "9": {
        "class_type": "ImageScale",
        "inputs": {
            "image": ["8", 0], "upscale_method": "nearest-exact",
            "width": 256, "height": 256, "crop": "disabled"
        }
    },
    "10": {
        "class_type": "SaveImage",
        "inputs": {"images": ["7", 0], "filename_prefix": ""}
    },
    "11": {
        "class_type": "SaveImage",
        "inputs": {"images": ["8", 0], "filename_prefix": ""}
    },
    "12": {
        "class_type": "SaveImage",
        "inputs": {"images": ["9", 0], "filename_prefix": ""}
    }
}


def cos_seed(variant_index: int, offset: float, amplitude: float,
             frequency: float, x_shift: float) -> int:
    """Compute a seed using a cosine curve. Always returns a positive int."""
    raw = amplitude * math.cos(frequency * variant_index + x_shift) + offset
    return int(abs(raw))


def build_prompt(positive: str, negative: str, asset_name: str,
                 category: str, seed: int) -> dict:
    workflow = json.loads(json.dumps(WORKFLOW_API))
    workflow["3"]["inputs"]["text"] = positive
    workflow["4"]["inputs"]["text"] = negative
    workflow["6"]["inputs"]["seed"] = seed
    workflow["10"]["inputs"]["filename_prefix"] = f"ScarForge/full/{category}/{asset_name}"
    workflow["11"]["inputs"]["filename_prefix"] = f"ScarForge/tiles/{category}/{asset_name}"
    workflow["12"]["inputs"]["filename_prefix"] = f"ScarForge/preview/{category}/{asset_name}"
    return {"prompt": workflow}


def queue_prompt(payload: dict, server: str) -> dict:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{server}/prompt", data=data,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def main():
    parser = argparse.ArgumentParser(
        description="Generate race/expression variations with cos-seed curves")
    parser.add_argument("batch", help="Batch name (e.g. elves, orcs)")
    parser.add_argument("--host", default=COMFYUI_DEFAULT,
                        help=f"ComfyUI server URL (default: {COMFYUI_DEFAULT})")
    parser.add_argument("--offset", type=float, default=100000,
                        help="Base seed region — shifts entire curve (default: 100000)")
    parser.add_argument("--amplitude", type=float, default=10000,
                        help="How far variants spread from each other (default: 10000)")
    parser.add_argument("--frequency", type=float, default=1.2,
                        help="Controls clustering vs even spacing (default: 1.2)")
    parser.add_argument("--x-shift", type=float, default=0.0,
                        help="Slide to a different 'family' of variants (default: 0.0)")
    parser.add_argument("--delay", type=float, default=1.0,
                        help="Seconds between submissions (default: 1.0)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview seeds and prompts without queuing")
    args = parser.parse_args()

    # Locate batch file
    script_dir = Path(__file__).parent.parent / "workflows"
    if not script_dir.exists():
        script_dir = Path("workflows")
    batch_path = script_dir / f"scarforge-batch-{args.batch}.json"
    if not batch_path.exists():
        print(f"ERROR: Batch file not found: {batch_path}")
        sys.exit(1)

    with open(batch_path) as f:
        data = json.load(f)
    prompts = data["prompts"]
    negative = data["negative"]
    category = args.batch

    # Compute seeds
    variant_names = list(prompts.keys())
    seeds = [
        cos_seed(i, args.offset, args.amplitude, args.frequency, args.x_shift)
        for i in range(len(variant_names))
    ]

    print(f"ScarForge Variation Generator (cos-seed)")
    print(f"  Batch:     {args.batch} ({len(variant_names)} variants)")
    print(f"  Server:    {args.host}")
    print(f"  Curve:     offset={args.offset}  amplitude={args.amplitude}  "
          f"frequency={args.frequency}  x_shift={args.x_shift}")
    print(f"  Seeds:     {seeds}")
    print()

    for i, name in enumerate(variant_names):
        seed = seeds[i]
        positive = prompts[name]
        payload = build_prompt(positive, negative, name, category, seed)

        if args.dry_run:
            print(f"  [{i+1}/{len(variant_names)}] {name}  seed={seed}")
            continue

        try:
            result = queue_prompt(payload, args.host)
            prompt_id = result.get("prompt_id", "???")
            print(f"  [{i+1}/{len(variant_names)}] {name}  seed={seed}  — queued: {prompt_id}")
        except urllib.error.URLError as e:
            print(f"  [{i+1}/{len(variant_names)}] {name}  — FAILED: {e}")
            print(f"  Is ComfyUI running at {args.host}?")
            sys.exit(1)

        if i < len(variant_names) - 1:
            time.sleep(args.delay)

    print()
    if args.dry_run:
        print("Dry run complete. No prompts were queued.")
        print("Run again without --dry-run to submit to ComfyUI.")
    else:
        print(f"All {len(variant_names)} variants queued.")
        print(f"Output: ComfyUI/output/ScarForge/{{full,tiles,preview}}/{category}/")
    print()
    print("Tip: change --x-shift to get a different 'family' of the same 5 variants.")
    print("     change --amplitude to control how different they are from each other.")


if __name__ == "__main__":
    main()
