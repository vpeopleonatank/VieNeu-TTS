<#
  Builds an OFFLINE Windows installer for the VieNeu-TTS web UI (CPU / ONNX, v3 Turbo + v3 Nano).

  Run on a machine WITH internet. The produced installer needs none:
    - embeddable Python 3.12 + every wheel pre-installed
    - Hugging Face model snapshots bundled as an HF cache (launcher sets HF_HUB_OFFLINE=1)

  Requirements on the build machine: uv, Inno Setup 6 (iscc.exe; `winget install JRSoftware.InnoSetup`).

  Usage:  powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1 [-SkipModels] [-SkipInstaller]
  Output: installer\dist\VieNeu-TTS-Setup-<version>.exe
#>
[CmdletBinding()]
param(
    [string]$PythonVersion = "3.12.10",
    [switch]$SkipModels,      # reuse installer\build\stage\hf_cache from a previous run
    [switch]$SkipInstaller    # only produce the stage folder
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Root  = Resolve-Path (Join-Path $PSScriptRoot "..")
$Build = Join-Path $PSScriptRoot "build"
$Stage = Join-Path $Build "stage"
$Py    = Join-Path $Stage "python"
$App   = Join-Path $Stage "app"
$Cache = Join-Path $Stage "hf_cache"

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Run($exe, [string[]]$a) { & $exe @a; if ($LASTEXITCODE -ne 0) { throw "$exe failed ($LASTEXITCODE)" } }

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { throw "uv not found in PATH" }

$version = (Select-String -Path (Join-Path $Root "pyproject.toml") -Pattern '^version\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
Write-Host "VieNeu-TTS $version"

# ---------------------------------------------------------------- python
Step "Embeddable Python $PythonVersion"
if (Test-Path $Py) { Remove-Item $Py -Recurse -Force }
New-Item -ItemType Directory -Force $Py, $Build | Out-Null
$zip = Join-Path $Build "python-$PythonVersion-embed-amd64.zip"
if (-not (Test-Path $zip)) {
    Invoke-WebRequest "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip" -OutFile $zip
}
Expand-Archive $zip -DestinationPath $Py -Force

# Embedded Python ignores PYTHONPATH when a ._pth exists: list every path here (relative to python\).
$pth = Get-ChildItem $Py -Filter "python*._pth" | Select-Object -First 1
$stem = $pth.BaseName -replace '\._pth$', ''
@(
    "$stem.zip", ".", "Lib\site-packages", "..\app\src", "..\app", "import site"
) | Set-Content $pth.FullName -Encoding ascii

# ---------------------------------------------------------------- wheels
Step "Installing runtime dependencies (torch-free core)"
$req = Join-Path $Build "requirements.txt"
Push-Location $Root
try {
    Run uv @("export", "--frozen", "--no-dev", "--no-hashes", "--no-emit-project", "--no-header", "--quiet", "-o", $req)
} finally { Pop-Location }
Run uv @("pip", "install", "--target", (Join-Path $Py "Lib\site-packages"),
         "--python-version", "3.12", "--python-platform", "windows",
         "--only-binary", ":all:", "--no-cache-dir", "-r", $req)
Get-ChildItem (Join-Path $Py "Lib\site-packages") -Filter "*.whl" | Remove-Item -Force

# ---------------------------------------------------------------- app source
Step "Copying application source"
if (Test-Path $App) { Remove-Item $App -Recurse -Force }
New-Item -ItemType Directory -Force $App | Out-Null
foreach ($d in "src", "apps", "examples", "client") { Copy-Item (Join-Path $Root $d) (Join-Path $App $d) -Recurse }
Copy-Item (Join-Path $Root "config.yaml") $App
Copy-Item (Join-Path $Root "LICENSE") $Stage
Get-ChildItem $Stage -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot "VieNeu-TTS.cmd") $Stage

# ---------------------------------------------------------------- models
if (-not $SkipModels) {
    Step "Downloading models into bundled HF cache"
    if (Test-Path $Cache) { Remove-Item $Cache -Recurse -Force }
    $dl = Join-Path $Build "download_models.py"
    @'
import sys
from huggingface_hub import snapshot_download
cache = sys.argv[1]
jobs = [
    # v3 Turbo, CPU/ONNX path (fp32 "onnx_update" default + int8) + speaker encoder + denoiser
    ("pnnbao-ump/VieNeu-TTS-v3-Turbo",
     ["config.json", "tokenizer*.json", "special_tokens_map.json", "voices*.json",
      "onnx_update/*", "onnx_int8/*", "speaker_encoder.onnx", "denoiser.onnx"]),
    ("OpenMOSS-Team/MOSS-Audio-Tokenizer-Nano-ONNX", None),
    # v3 Nano (preview)
    ("pnnbao-ump/VieNeu-TTS-v3-Nano", None),
]
for repo, allow in jobs:
    print("->", repo, flush=True)
    snapshot_download(repo, cache_dir=cache, allow_patterns=allow)
'@ | Set-Content $dl -Encoding utf8
    Run uv @("run", "--no-project", "--with", "huggingface_hub", "python", $dl, $Cache)
}
if (-not (Test-Path $Cache)) { throw "hf_cache missing; run without -SkipModels first" }

# HF cache snapshots are symlinks into blobs\. ONNX Runtime rejects external-data paths that resolve
# outside the model dir, and symlinks don't survive installation anyway -> make real files, drop blobs\.
Step "Materializing HF cache (symlinks -> files)"
$mat = Join-Path $Build "materialize_cache.py"
@'
import os, shutil, sys
cache = sys.argv[1]
for repo in os.listdir(cache):
    snaps = os.path.join(cache, repo, "snapshots")
    if not os.path.isdir(snaps):
        continue
    for dp, _, files in os.walk(snaps):
        for f in files:
            p = os.path.join(dp, f)
            if os.path.islink(p):
                real = os.path.realpath(p)
                os.remove(p)
                shutil.copy2(real, p)
    shutil.rmtree(os.path.join(cache, repo, "blobs"), ignore_errors=True)
shutil.rmtree(os.path.join(cache, "blobs"), ignore_errors=True)   # shared (hf-xet) blobs at cache root
print("materialized")
'@ | Set-Content $mat -Encoding utf8
Run uv @("run", "--no-project", "python", $mat, $Cache)

# ---------------------------------------------------------------- smoke test (offline)
Step "Smoke test: import + offline engine load"
$env:HF_HOME = $Cache; $env:HF_HUB_CACHE = $Cache; $env:HF_HUB_OFFLINE = "1"
$env:HF_HUB_DISABLE_TELEMETRY = "1"; $env:GRADIO_ANALYTICS_ENABLED = "False"
$smoke = Join-Path $Build "smoke.py"
@'
import apps.gradio_main  # noqa: F401  (import must work with no torch)
import sys
from vieneu import Vieneu
for mode in ("v3turbo", "v3nano"):
    tts = Vieneu(mode=mode)
    wav = tts.infer("Xin chào các bạn.")
    assert len(wav) > 1000, mode
    print(mode, "OK", len(wav))
assert "torch" not in sys.modules, "torch must not be needed"
'@ | Set-Content $smoke -Encoding utf8
Push-Location $App
try { Run (Join-Path $Py "python.exe") @($smoke) } finally { Pop-Location }

if ($SkipInstaller) { Write-Host "Stage ready: $Stage"; return }

# ---------------------------------------------------------------- installer
Step "Compiling installer (Inno Setup)"
$iscc = (Get-Command iscc -ErrorAction SilentlyContinue).Source
if (-not $iscc) {
    $iscc = @("$env:ProgramFiles\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
              "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $iscc) { throw "Inno Setup not found. Install: winget install JRSoftware.InnoSetup" }
Run $iscc @("/DAppVersion=$version", "/DStageDir=$Stage", "/DRootDir=$Root", (Join-Path $PSScriptRoot "vieneu.iss"))
Write-Host "`nDone: $(Join-Path $PSScriptRoot 'dist')" -ForegroundColor Green
