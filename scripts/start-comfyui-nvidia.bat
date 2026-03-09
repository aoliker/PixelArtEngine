@echo off
REM ============================================================================
REM ComfyUI Launcher for Windows (NVIDIA GPU / CUDA)
REM Project: ScarForge — Dark Fantasy Dungeon Crawler
REM
REM Uses --force-fp16 to fit SDXL in 8GB VRAM (RTX 3070)
REM ============================================================================

set "COMFYUI_DIR=%USERPROFILE%\ComfyUI"

if not exist "%COMFYUI_DIR%\main.py" (
    echo ERROR: ComfyUI not found at %COMFYUI_DIR%
    echo Run setup-comfyui-nvidia.bat first.
    pause
    exit /b 1
)

echo ============================================
echo  ScarForge — Starting ComfyUI
echo  GPU Mode: NVIDIA CUDA (fp16)
echo ============================================
echo.
echo  After startup, open: http://127.0.0.1:8188
echo  Load workflow: ScarForge/scarforge-pixelart-building.json
echo.

cd /d "%COMFYUI_DIR%"
call venv\Scripts\activate.bat
python main.py --force-fp16
