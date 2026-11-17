# Builds the Windows installer. Run from CI (or locally on Windows with uv, Node/pnpm
# and Inno Setup 6 installed):  pwsh installer/build.ps1
#
# Bundled into the installer (the Dockerfile's "everything prebuilt" idea):
#   - the wheel, with the frontend already built into it
#   - uv.exe and requirements.txt exported from uv.lock (exact locked versions)
#   - MuseScore (sheet music) and fluidsynth (auralization)
# Downloaded on the user's machine at install time: Python, PyTorch (CPU or CUDA
# to match their GPU), the soundfonts.
param(
    [string]$MuseScoreTag = "v4.7.4"   # same version as the Dockerfile
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Root = Split-Path $PSScriptRoot -Parent
$Stage = Join-Path $PSScriptRoot "stage"
$Dist = Join-Path $Root "dist"
Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$Stage\bin", "$Stage\wheel", "$Stage\musescore", "$Stage\fluidsynth", $Dist | Out-Null
$Tmp = Join-Path $PSScriptRoot "tmp"
New-Item -ItemType Directory -Force $Tmp | Out-Null

function Get-ReleaseAsset($repo, $tag, [string[]]$patterns, [string]$exclude = $null) {
    $headers = @{ "User-Agent" = "muscriptor-installer" }
    if ($env:GITHUB_TOKEN) { $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN" }
    $url = if ($tag) { "https://api.github.com/repos/$repo/releases/tags/$tag" } else { "https://api.github.com/repos/$repo/releases/latest" }
    $rel = Invoke-RestMethod $url -Headers $headers
    foreach ($p in $patterns) {
        $hit = $rel.assets | Where-Object { $_.name -match $p -and (-not $exclude -or $_.name -notmatch $exclude) } | Select-Object -First 1
        if ($hit) { return $hit }
    }
    throw "No asset of $repo $($rel.tag_name) matches [$($patterns -join ', ')]. Available: $($rel.assets.name -join ', ')"
}

function Download($asset) {
    $dest = Join-Path $Tmp $asset.name
    Write-Host "Downloading $($asset.name) ..."
    Invoke-WebRequest $asset.browser_download_url -OutFile $dest
    return $dest
}

# --- Python package -------------------------------------------------------
$Version = (Select-String -Path "$Root\pyproject.toml" -Pattern '^version = "(.+)"').Matches[0].Groups[1].Value
Write-Host "MuScriptor $Version"

if (-not (Test-Path "$Root\muscriptor\web_dist\index.html")) {
    throw "Frontend not built: run 'pnpm install --frozen-lockfile && pnpm run build' in web/ first."
}
uv build --wheel --out-dir "$Stage\wheel" $Root
if ($LASTEXITCODE) { throw "uv build failed" }

# Exact locked versions. No hashes: the CUDA wheels of torch are not the PyPI ones.
uv export --project $Root --frozen --no-dev --no-hashes --no-emit-project -o "$Stage\requirements.txt"
if ($LASTEXITCODE) { throw "uv export failed" }

# --- uv -------------------------------------------------------------------
$uv = Download (Get-ReleaseAsset "astral-sh/uv" $null @('^uv-x86_64-pc-windows-msvc\.zip$'))
Expand-Archive $uv "$Tmp\uv" -Force
Copy-Item (Get-ChildItem "$Tmp\uv" -Recurse -Filter uv.exe | Select-Object -First 1).FullName "$Stage\bin\uv.exe"

# --- fluidsynth -----------------------------------------------------------
$fs = Download (Get-ReleaseAsset "FluidSynth/fluidsynth" $null @('win10-x64\.zip$', 'win10-x64.*\.zip$') "cpp11")
Expand-Archive $fs "$Stage\fluidsynth" -Force

# --- MuseScore ------------------------------------------------------------
# Prefer a portable archive; fall back to extracting the MSI without installing it.
$ms = Get-ReleaseAsset "musescore/MuseScore" $MuseScoreTag @('x64.*\.7z$', 'x64.*\.zip$', 'x64.*\.msi$', 'x86_64.*\.(7z|zip|msi)$')
$msFile = Download $ms
switch -Regex ($ms.name) {
    '\.7z$'  { 7z x $msFile "-o$Stage\musescore" -y | Out-Null; if ($LASTEXITCODE) { throw "7z failed" } }
    '\.zip$' { Expand-Archive $msFile "$Stage\musescore" -Force }
    '\.msi$' {
        $p = Start-Process msiexec -ArgumentList "/a `"$msFile`" /qn TARGETDIR=`"$Stage\musescore`"" -Wait -PassThru
        if ($p.ExitCode) { throw "msiexec extraction failed ($($p.ExitCode))" }
    }
}
$exe = Get-ChildItem "$Stage\musescore" -Recurse -Filter "MuseScore*.exe" | Select-Object -First 1
if (-not $exe) { throw "No MuseScore*.exe found after extracting $($ms.name)" }
Write-Host "MuseScore: $($exe.FullName)"
Remove-Item "$Stage\musescore\*.msi" -ErrorAction SilentlyContinue

# --- Inno Setup -----------------------------------------------------------
$iscc = (Get-Command iscc -ErrorAction SilentlyContinue).Source
if (-not $iscc) { $iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
& $iscc "/DAppVersion=$Version" "$PSScriptRoot\muscriptor.iss"
if ($LASTEXITCODE) { throw "ISCC failed" }
Write-Host "Built: $(Get-ChildItem $Dist -Filter '*setup*.exe' | ForEach-Object FullName)"
