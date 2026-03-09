#!/usr/bin/env python3
"""
ScarForge — ComfyUI API Test Image Generator
Generates a dark fantasy medieval village building in 32x32 pixel art.

Usage:
    python generate-test-image.py [--server http://127.0.0.1:8188]

Requirements:
    - ComfyUI running locally (start with: python main.py --force-fp16)
    - SDXL base model + pixel-art-xl LoRA installed
"""

import argparse
import json
import os
import random
import sys
import time
import urllib.request
import urllib.error

WORKFLOW_PROMPT = {
    "1": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {
            "ckpt_name": "sd_xl_base_1.0.safetensors"
        }
    },
    "2": {
        "class_type": "LoraLoader",
        "inputs": {
            "lora_name": "pixel-art-xl.safetensors",
            "strength_model": 0.85,
            "strength_clip": 0.85,
            "model": ["1", 0],
            "clip": ["1", 1]
        }
    },
    "3": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": (
                "pixel, pixel art, top-down view, dark fantasy medieval village building, "
                "stone and timber tavern, mossy roof, warm lantern light from windows, "
                "cobblestone path, gritty atmosphere, muted dark palette, 32x32 tile sprite, "
                "game asset, detailed shading, clean pixel edges"
            ),
            "clip": ["2", 1]
        }
    },
    "4": {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": (
                "blurry, smooth gradients, anti-aliasing, 3d render, realistic, photographic, "
                "modern, futuristic, sci-fi, bright colors, neon, watermark, text, signature, "
                "jpeg artifacts, low quality, deformed, ugly, oversaturated, bloom, glow effects"
            ),
            "clip": ["2", 1]
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
            "seed": 42,
            "steps": 30,
            "cfg": 7.5,
            "sampler_name": "euler_ancestral",
            "scheduler": "normal",
            "denoise": 1.0,
            "model": ["2", 0],
            "positive": ["3", 0],
            "negative": ["4", 0],
            "latent_image": ["5", 0]
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
            "upscale_method": "nearest-exact",
            "width": 32,
            "height": 32,
            "crop": "disabled",
            "image": ["7", 0]
        }
    },
    "9": {
        "class_type": "ImageScale",
        "inputs": {
            "upscale_method": "nearest-exact",
            "width": 256,
            "height": 256,
            "crop": "disabled",
            "image": ["8", 0]
        }
    },
    "10": {
        "class_type": "SaveImage",
        "inputs": {
            "filename_prefix": "ScarForge/full/building",
            "images": ["7", 0]
        }
    },
    "11": {
        "class_type": "SaveImage",
        "inputs": {
            "filename_prefix": "ScarForge/tiles/building_32",
            "images": ["8", 0]
        }
    },
    "12": {
        "class_type": "SaveImage",
        "inputs": {
            "filename_prefix": "ScarForge/preview/building_preview",
            "images": ["9", 0]
        }
    }
}


def queue_prompt(server: str, prompt: dict, seed: int | None = None) -> dict:
    """Send a prompt to the ComfyUI API and return the response."""
    if seed is not None:
        prompt["6"]["inputs"]["seed"] = seed

    payload = json.dumps({"prompt": prompt}).encode("utf-8")
    req = urllib.request.Request(
        f"{server}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def wait_for_completion(server: str, prompt_id: str, timeout: int = 300):
    """Poll the history endpoint until the prompt completes."""
    start = time.time()
    while time.time() - start < timeout:
        try:
            req = urllib.request.Request(f"{server}/history/{prompt_id}")
            with urllib.request.urlopen(req) as resp:
                history = json.loads(resp.read())
            if prompt_id in history:
                return history[prompt_id]
        except urllib.error.URLError:
            pass
        time.sleep(2)
    raise TimeoutError(f"Prompt {prompt_id} did not complete within {timeout}s")


def main():
    parser = argparse.ArgumentParser(description="Generate ScarForge pixel art test image")
    parser.add_argument("--server", default="http://127.0.0.1:8188", help="ComfyUI server URL")
    parser.add_argument("--seed", type=int, default=None, help="RNG seed (random if not set)")
    parser.add_argument("--prompt-text", type=str, default=None, help="Override positive prompt")
    args = parser.parse_args()

    seed = args.seed if args.seed is not None else random.randint(0, 2**32 - 1)
    prompt = WORKFLOW_PROMPT.copy()

    if args.prompt_text:
        prompt["3"]["inputs"]["text"] = args.prompt_text

    print(f"ScarForge Pixel Art Generator")
    print(f"  Server:  {args.server}")
    print(f"  Seed:    {seed}")
    print()

    # Check server is reachable
    try:
        urllib.request.urlopen(f"{args.server}/system_stats")
    except urllib.error.URLError:
        print(f"ERROR: Cannot reach ComfyUI at {args.server}")
        print("Start ComfyUI first:")
        print("  cd ~/ComfyUI && source venv/bin/activate && python main.py --force-fp16")
        sys.exit(1)

    print("Queueing prompt...")
    result = queue_prompt(args.server, prompt, seed)
    prompt_id = result["prompt_id"]
    print(f"  Prompt ID: {prompt_id}")
    print("  Generating (this takes ~30-90s on Apple Silicon)...")

    history = wait_for_completion(args.server, prompt_id)

    print()
    print("Done! Output images saved to ComfyUI/output/ScarForge/")
    print("  • full/      — 1024x1024 high-res reference")
    print("  • tiles/     — 32x32 actual game tile")
    print("  • preview/   — 256x256 preview (8x upscale, nearest-neighbor)")

    # Print output filenames
    if "outputs" in history:
        for node_id, output in history["outputs"].items():
            if "images" in output:
                for img in output["images"]:
                    print(f"  → {img.get('subfolder', '')}/{img['filename']}")


if __name__ == "__main__":
    main()
