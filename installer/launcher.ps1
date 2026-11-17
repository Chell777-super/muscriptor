# MuScriptor launcher. No arguments: start the web UI and open it in the browser.
# With arguments: forwarded to the muscriptor CLI (e.g. `transcribe song.mp3`).
$ErrorActionPreference = "Stop"
$App = $PSScriptRoot
$Py = Join-Path $App "venv\Scripts\python.exe"

# Weights and soundfonts live in the install dir (prefetched at install time).
# Only the cache moves: the HuggingFace login token stays where `hf` puts it.
$env:HF_HUB_CACHE = Join-Path $App "hf-cache"
$env:PYTHONUTF8 = "1"

function Find-Exe($dir, $name) {
    $f = Get-ChildItem -Path (Join-Path $App $dir) -Recurse -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { $f.FullName }
}

# fluidsynth is looked up on PATH (MIDI auralization); MuseScore through the
# env var (sheet music).
$fluid = Find-Exe "fluidsynth" "fluidsynth.exe"
if ($fluid) { $env:PATH = "$(Split-Path $fluid);$env:PATH" }
$mscore = Find-Exe "musescore" "MuseScore*.exe"
if ($mscore -and -not $env:MUSCRIPTOR_MUSESCORE) { $env:MUSCRIPTOR_MUSESCORE = $mscore }

# The model weights are gated: make sure the user is logged in to HuggingFace.
$hfHome = if ($env:HF_HOME) { $env:HF_HOME } else { Join-Path $HOME ".cache\huggingface" }
if (-not $env:HF_TOKEN -and -not (Test-Path (Join-Path $hfHome "token"))) {
    Write-Host ""
    Write-Host "MuScriptor needs a (free) HuggingFace account to download the model."
    Write-Host "  1. Accept the license at https://huggingface.co/MuScriptor/muscriptor-medium"
    Write-Host "  2. Paste a read token from https://huggingface.co/settings/tokens below."
    Write-Host ""
    & (Join-Path $App "venv\Scripts\hf.exe") auth login
}

if ($args.Count -gt 0) {
    & $Py -m muscriptor @args
    exit $LASTEXITCODE
}

# Web UI: open the browser as soon as the server answers (model loading can take a while).
$port = 8222
Start-Job -ScriptBlock {
    param($url)
    for ($i = 0; $i -lt 600; $i++) {
        try { Invoke-RestMethod "$url/health" -TimeoutSec 2 | Out-Null; Start-Process $url; return } catch { Start-Sleep 1 }
    }
} -ArgumentList "http://127.0.0.1:$port" | Out-Null

Write-Host "Starting MuScriptor on http://127.0.0.1:$port (close this window to stop)."
& $Py -m muscriptor serve --port $port
exit $LASTEXITCODE
