@echo off
REM ============================================================================
REM ComfyUI Setup for Windows (NVIDIA GPU / CUDA Backend)
REM Project: ScarForge — Dark Fantasy Dungeon Crawler
REM Target:  NVIDIA RTX 3070 (8GB VRAM) with CUDA
REM ============================================================================
setlocal enabledelayedexpansion

set "COMFYUI_DIR=%USERPROFILE%\ComfyUI"

echo ============================================
echo  ScarForge — ComfyUI Pixel Art Setup
echo  Target: Windows + NVIDIA GPU (CUDA)
echo ============================================
echo.

REM -------------------------------------------------------------------
REM 1. Check prerequisites
REM -------------------------------------------------------------------
echo [1/7] Checking prerequisites...

REM Python version check
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH.
    echo Install Python 3.10+ from https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during install.
    exit /b 1
)

for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set "PY_VERSION=%%v"
for /f "tokens=1,2 delims=." %%a in ("%PY_VERSION%") do (
    set "PY_MAJOR=%%a"
    set "PY_MINOR=%%b"
)

if %PY_MAJOR% LSS 3 (
    echo ERROR: Python 3.10+ required. Found: %PY_VERSION%
    exit /b 1
)
if %PY_MAJOR% EQU 3 if %PY_MINOR% LSS 10 (
    echo ERROR: Python 3.10+ required. Found: %PY_VERSION%
    exit /b 1
)
echo   Python %PY_VERSION% OK

REM Check for git
git --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: git is not installed. Install from https://git-scm.com/download/win
    exit /b 1
)
echo   git OK

REM Check for NVIDIA driver / nvidia-smi
nvidia-smi >nul 2>&1
if errorlevel 1 (
    echo WARNING: nvidia-smi not found. NVIDIA drivers may not be installed.
    echo Install the latest drivers from https://www.nvidia.com/Download/index.aspx
    echo Continuing anyway...
) else (
    echo   NVIDIA GPU detected OK
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
)

REM -------------------------------------------------------------------
REM 2. Clone ComfyUI
REM -------------------------------------------------------------------
echo.
echo [2/7] Setting up ComfyUI at %COMFYUI_DIR%...

if exist "%COMFYUI_DIR%\.git" (
    echo   ComfyUI directory exists, pulling latest...
    pushd "%COMFYUI_DIR%"
    git pull
    popd
) else (
    git clone https://github.com/comfyanonymous/ComfyUI.git "%COMFYUI_DIR%"
)

REM -------------------------------------------------------------------
REM 3. Create venv and install dependencies with CUDA support
REM -------------------------------------------------------------------
echo.
echo [3/7] Creating virtual environment and installing dependencies...

if not exist "%COMFYUI_DIR%\venv" (
    python -m venv "%COMFYUI_DIR%\venv"
)

call "%COMFYUI_DIR%\venv\Scripts\activate.bat"

pip install --upgrade pip

REM Install PyTorch with CUDA 12.1 support (compatible with RTX 3070)
echo   Installing PyTorch with CUDA support...
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

REM Install ComfyUI requirements
pip install -r "%COMFYUI_DIR%\requirements.txt"

REM Verify CUDA availability
python -c "import torch; print(f'  PyTorch {torch.__version__}'); print(f'  CUDA available: {torch.cuda.is_available()}'); print(f'  GPU: {torch.cuda.get_device_name(0)}') if torch.cuda.is_available() else print('  WARNING: CUDA not available')"

REM -------------------------------------------------------------------
REM 4. Download SDXL base model
REM -------------------------------------------------------------------
echo.
echo [4/7] Downloading SDXL base model...

set "MODELS_DIR=%COMFYUI_DIR%\models\checkpoints"
set "SDXL_MODEL=%MODELS_DIR%\sd_xl_base_1.0.safetensors"

if exist "%SDXL_MODEL%" (
    echo   SDXL base model already exists OK
) else (
    echo   Downloading stabilityai/stable-diffusion-xl-base-1.0...
    echo   (This is ~6.9 GB, may take a while^)

    pip install huggingface_hub

    python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='stabilityai/stable-diffusion-xl-base-1.0', filename='sd_xl_base_1.0.safetensors', local_dir=r'%MODELS_DIR%', local_dir_use_symlinks=False)"

    if errorlevel 1 (
        echo   ERROR: Failed to download SDXL model. Check your internet connection.
        exit /b 1
    )
    echo   SDXL base model downloaded OK
)

REM -------------------------------------------------------------------
REM 5. Download pixel-art-xl LoRA
REM -------------------------------------------------------------------
echo.
echo [5/7] Downloading pixel-art-xl LoRA...

set "LORA_DIR=%COMFYUI_DIR%\models\loras"
if not exist "%LORA_DIR%" mkdir "%LORA_DIR%"
set "LORA_FILE=%LORA_DIR%\pixel-art-xl.safetensors"

if exist "%LORA_FILE%" (
    echo   pixel-art-xl LoRA already exists OK
) else (
    echo   Downloading nerijs/pixel-art-xl...
    python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='nerijs/pixel-art-xl', filename='pixel-art-xl.safetensors', local_dir=r'%LORA_DIR%', local_dir_use_symlinks=False)"

    if errorlevel 1 (
        echo   ERROR: Failed to download pixel-art-xl LoRA.
        exit /b 1
    )
    echo   pixel-art-xl LoRA downloaded OK
)

REM -------------------------------------------------------------------
REM 6. Install PixelArt-Detector custom node
REM -------------------------------------------------------------------
echo.
echo [6/7] Installing ComfyUI-PixelArt-Detector plugin...

set "CUSTOM_NODES_DIR=%COMFYUI_DIR%\custom_nodes"
set "PIXELART_DIR=%CUSTOM_NODES_DIR%\ComfyUI-PixelArt-Detector"

if exist "%PIXELART_DIR%\.git" (
    echo   Plugin exists, pulling latest...
    pushd "%PIXELART_DIR%"
    git pull
    popd
) else (
    pushd "%CUSTOM_NODES_DIR%"
    git clone https://github.com/dimtoneff/ComfyUI-PixelArt-Detector.git
    popd
)

REM Install plugin dependencies if any
if exist "%PIXELART_DIR%\requirements.txt" (
    pip install -r "%PIXELART_DIR%\requirements.txt"
)

REM -------------------------------------------------------------------
REM 7. Copy ScarForge workflows
REM -------------------------------------------------------------------
echo.
echo [7/7] Setting up ScarForge workflows...

set "SCRIPT_DIR=%~dp0"
set "WORKFLOW_SRC=%SCRIPT_DIR%..\workflows"

if exist "%WORKFLOW_SRC%" (
    if not exist "%COMFYUI_DIR%\user\default\workflows\ScarForge" (
        mkdir "%COMFYUI_DIR%\user\default\workflows\ScarForge"
    )
    copy /Y "%WORKFLOW_SRC%\*.json" "%COMFYUI_DIR%\user\default\workflows\ScarForge\" >nul 2>&1
    echo   Workflows copied OK
) else (
    echo   No workflow directory found, skipping.
)

REM -------------------------------------------------------------------
REM Done!
REM -------------------------------------------------------------------
echo.
echo ============================================
echo  Setup Complete!
echo ============================================
echo.
echo  To start ComfyUI, run:
echo    start-comfyui-nvidia.bat
echo.
echo  Or manually:
echo    cd %COMFYUI_DIR%
echo    venv\Scripts\activate.bat
echo    python main.py --force-fp16
echo.
echo  Then open http://127.0.0.1:8188 in your browser.
echo.
echo  --force-fp16 is recommended for 8GB VRAM GPUs
echo  (RTX 3070) to reduce memory usage with SDXL.
echo.
echo  Installed components:
echo    * SDXL Base 1.0 checkpoint
echo    * pixel-art-xl LoRA (trigger word: 'pixel')
echo    * ComfyUI-PixelArt-Detector node
echo    * ScarForge pixel art workflows
echo.
echo  Next: Load the ScarForge workflow from the
echo  workflows menu and hit 'Queue Prompt'!
echo ============================================

endlocal
