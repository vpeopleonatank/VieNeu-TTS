@echo off
setlocal
title VieNeu-TTS
set "HERE=%~dp0"

rem Fully offline: models come from the bundled Hugging Face cache.
set "HF_HOME=%HERE%hf_cache"
set "HF_HUB_CACHE=%HERE%hf_cache"
set "HF_HUB_OFFLINE=1"
set "TRANSFORMERS_OFFLINE=1"
set "HF_HUB_DISABLE_TELEMETRY=1"
set "GRADIO_ANALYTICS_ENABLED=False"
set "PYTHONUTF8=1"
set "PYTHONDONTWRITEBYTECODE=1"
if not defined GRADIO_SERVER_PORT set "GRADIO_SERVER_PORT=7860"
set "GRADIO_SERVER_NAME=127.0.0.1"

cd /d "%HERE%app"
start "" /b cmd /c "timeout /t 10 /nobreak >nul & start "" http://127.0.0.1:%GRADIO_SERVER_PORT%"
"%HERE%python\python.exe" -c "from apps.gradio_main import main; main()"
if errorlevel 1 pause
