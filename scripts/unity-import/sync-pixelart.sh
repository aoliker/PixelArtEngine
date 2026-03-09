#!/usr/bin/env bash
# ============================================================================
# sync-pixelart.sh — Sync generated pixel art from Google Drive to Unity
# Project: ScarForge — Dark Fantasy Dungeon Crawler
#
# Prerequisites:
#   brew install --cask google-drive   (Google Drive for Desktop)
#   — OR —
#   brew install rclone                (configure with: rclone config)
#
# Usage:
#   ./sync-pixelart.sh                           # default paths
#   ./sync-pixelart.sh --watch                   # continuous watch mode
#   UNITY_PROJECT=/path/to/project ./sync-pixelart.sh
# ============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
UNITY_PROJECT="${UNITY_PROJECT:-/Users/Shared/UnityProjects/DreamRPG}"
SPRITES_DIR="$UNITY_PROJECT/Assets/Sprites"

# Google Drive for Desktop mount path (macOS default)
GDRIVE_MOUNT="/Volumes/GoogleDrive/My Drive"
# Fallback: check the newer mount path
if [ ! -d "$GDRIVE_MOUNT" ]; then
    GDRIVE_MOUNT="$HOME/Library/CloudStorage/GoogleDrive-*/My Drive"
    # Expand glob
    GDRIVE_MOUNT=$(echo $GDRIVE_MOUNT)
fi

# Subfolder within Google Drive where ComfyUI outputs land
GDRIVE_PIXELART_FOLDER="${GDRIVE_PIXELART_FOLDER:-PixelArtEngine/output}"
SOURCE_DIR="$GDRIVE_MOUNT/$GDRIVE_PIXELART_FOLDER"

WATCH_MODE=false
SYNC_INTERVAL=10  # seconds between checks in watch mode

# --- Parse args --------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --watch) WATCH_MODE=true ;;
        --help|-h)
            echo "Usage: $0 [--watch]"
            echo ""
            echo "Syncs new PNG files from Google Drive to Unity Assets/Sprites/"
            echo ""
            echo "Environment variables:"
            echo "  UNITY_PROJECT          Path to Unity project (default: /Users/Shared/UnityProjects/DreamRPG)"
            echo "  GDRIVE_PIXELART_FOLDER Subfolder in Google Drive (default: PixelArtEngine/output)"
            echo ""
            echo "Options:"
            echo "  --watch    Continuously watch for new files"
            exit 0
            ;;
    esac
done

# --- Validation --------------------------------------------------------------
echo "============================================"
echo " ScarForge — Pixel Art Sync"
echo "============================================"
echo ""

if [ ! -d "$UNITY_PROJECT" ]; then
    echo "ERROR: Unity project not found at $UNITY_PROJECT"
    echo "Set UNITY_PROJECT to the correct path."
    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Google Drive source folder not found at:"
    echo "  $SOURCE_DIR"
    echo ""
    echo "Make sure:"
    echo "  1. Google Drive for Desktop is running"
    echo "  2. The folder exists in your Drive"
    echo "  3. Or set GDRIVE_PIXELART_FOLDER to the correct subfolder"
    exit 1
fi

mkdir -p "$SPRITES_DIR"

echo "Source:  $SOURCE_DIR"
echo "Target:  $SPRITES_DIR"
echo ""

# --- Tracking file for incremental sync -------------------------------------
SYNC_STATE="$UNITY_PROJECT/.pixelart-sync-state"
touch "$SYNC_STATE"

# --- Sync function -----------------------------------------------------------
sync_new_files() {
    local count=0

    while IFS= read -r -d '' png_file; do
        local filename
        filename=$(basename "$png_file")

        # Skip if already synced
        if grep -qxF "$filename" "$SYNC_STATE" 2>/dev/null; then
            continue
        fi

        # Determine target subfolder based on filename convention:
        #   tile_floor_*.png  -> Assets/Sprites/Tiles/Floor/
        #   tile_wall_*.png   -> Assets/Sprites/Tiles/Wall/
        #   char_*.png        -> Assets/Sprites/Characters/
        #   prop_*.png        -> Assets/Sprites/Props/
        #   *                 -> Assets/Sprites/Unsorted/
        local subdir="Unsorted"
        case "$filename" in
            tile_floor_*) subdir="Tiles/Floor" ;;
            tile_wall_*)  subdir="Tiles/Wall" ;;
            tile_door_*)  subdir="Tiles/Door" ;;
            tile_stair_*) subdir="Tiles/Stair" ;;
            tile_*)       subdir="Tiles" ;;
            char_*)       subdir="Characters" ;;
            prop_*)       subdir="Props" ;;
            ui_*)         subdir="UI" ;;
            fx_*)         subdir="Effects" ;;
        esac

        local target_dir="$SPRITES_DIR/$subdir"
        mkdir -p "$target_dir"

        cp "$png_file" "$target_dir/$filename"
        echo "$filename" >> "$SYNC_STATE"
        echo "  + $subdir/$filename"
        count=$((count + 1))

    done < <(find "$SOURCE_DIR" -maxdepth 2 -name '*.png' -print0 2>/dev/null)

    if [ "$count" -gt 0 ]; then
        echo "  Synced $count new file(s)."
        echo ""
        echo "  Unity will auto-import with PixelArtImporter settings:"
        echo "    Filter: Point | Compression: None | PPU: 32"
        echo "    Tile assets created in Assets/Tiles/"
    fi

    return $count
}

# --- Execute -----------------------------------------------------------------
if [ "$WATCH_MODE" = true ]; then
    echo "Watching for new files (Ctrl+C to stop)..."
    echo ""
    while true; do
        sync_new_files || true
        sleep "$SYNC_INTERVAL"
    done
else
    echo "Syncing..."
    sync_new_files || true
    echo ""
    echo "Done. Run with --watch for continuous sync."
fi
