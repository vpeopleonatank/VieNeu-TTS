# Offline Windows installer

Builds `VieNeu-TTS-Setup-<version>.exe` (~1.4 GB) that installs the Gradio web UI with
**no internet and no Python/uv needed on the target machine**. CPU only (ONNX Runtime).

Bundled: embeddable Python 3.12, all wheels from `uv.lock` (torch-free core), and Hugging Face
snapshots for **v3 Turbo** (fp32 + int8 ONNX, speaker encoder, denoiser), the MOSS ONNX codec and
**v3 Nano**. The launcher sets `HF_HOME` to the bundled `hf_cache\` and `HF_HUB_OFFLINE=1`.

## Build (needs internet, once)

Requires `uv` and Inno Setup 6 (`winget install JRSoftware.InnoSetup`).

```powershell
powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
```

| Flag | Effect |
|---|---|
| `-SkipModels` | reuse `installer\build\stage\hf_cache` (skip ~1 GB download) |
| `-SkipInstaller` | stop after staging + offline smoke test |
| `-PythonVersion` | embeddable Python version (default `3.12.10`; must stay 3.12 to match the lock/wheels) |

The build runs an **offline** synthesis smoke test (Turbo + Nano) against the staged files before
compiling; output is `installer\dist\`.

## Install

Per-user by default (`%LOCALAPPDATA%\Programs\VieNeu-TTS`, no admin). Silent:
`VieNeu-TTS-Setup-x.y.z.exe /VERYSILENT /DIR=C:\VieNeu`. Start Menu / desktop shortcut runs
`VieNeu-TTS.cmd` → http://127.0.0.1:7860 (override with `GRADIO_SERVER_PORT`). Saved voices go to
`~/.vieneu` (override with `VIENEU_HOME`).

## Adding/removing models

Edit the `jobs` list in `build_installer.ps1`. Not bundled (need torch/GPU or other repos): v2/v1 GPU
models, GGUF, custom-model merge. Selecting them offline fails by design.
