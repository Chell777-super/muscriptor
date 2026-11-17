# Downloads for install.bat: the prebuilt web UI and FluidSynth.
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][ValidateSet('webui', 'fluidsynth')][string]$What
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is 10x slower with it
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tmp = Join-Path $env:TEMP ("muscriptor-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
    if ($What -eq 'webui') {
        # web_dist is gitignored; the PyPI wheel of the same version ships it built.
        $ver = (Select-String -Path (Join-Path $Root 'pyproject.toml') -Pattern '^version\s*=\s*"([^"]+)"' |
                Select-Object -First 1).Matches[0].Groups[1].Value
        try {
            $meta = Invoke-RestMethod "https://pypi.org/pypi/muscriptor/$ver/json"
        } catch {
            Write-Host "    muscriptor $ver is not on PyPI, using the latest release's web UI"
            $meta = Invoke-RestMethod "https://pypi.org/pypi/muscriptor/json"
        }
        $whl = $meta.urls | Where-Object { $_.packagetype -eq 'bdist_wheel' } | Select-Object -First 1
        if (-not $whl) { throw 'no wheel found on PyPI' }
        Write-Host "    $($whl.filename)"
        $file = Join-Path $tmp $whl.filename
        Invoke-WebRequest $whl.url -OutFile $file -UseBasicParsing
        $dest = Join-Path $Root 'muscriptor\web_dist'
        $prefix = 'muscriptor/web_dist/'
        $zip = [IO.Compression.ZipFile]::OpenRead($file)
        try {
            $n = 0
            foreach ($e in $zip.Entries) {
                if (-not $e.FullName.StartsWith($prefix) -or $e.FullName.EndsWith('/')) { continue }
                $out = Join-Path $dest ($e.FullName.Substring($prefix.Length) -replace '/', '\')
                New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
                $n++
            }
        } finally { $zip.Dispose() }
        if ($n -eq 0) { throw 'the wheel has no web_dist' }
        Write-Host "    $n files -> $dest"
    }
    else {
        $dest = Join-Path $Root 'windows\tools\fluidsynth'
        $rel = Invoke-RestMethod 'https://api.github.com/repos/FluidSynth/fluidsynth/releases/latest' `
                -Headers @{ 'User-Agent' = 'muscriptor-windows-installer' }
        $asset = $rel.assets | Where-Object { $_.name -match 'win10-x64.*\.zip$' } |
                 Sort-Object { $_.name.Length } | Select-Object -First 1
        if (-not $asset) { throw "no win10-x64 zip in FluidSynth $($rel.tag_name)" }
        Write-Host "    $($asset.name)"
        $file = Join-Path $tmp $asset.name
        Invoke-WebRequest $asset.browser_download_url -OutFile $file -UseBasicParsing
        $unz = Join-Path $tmp 'unzipped'
        Expand-Archive -Path $file -DestinationPath $unz -Force
        $exe = Get-ChildItem $unz -Recurse -Filter 'fluidsynth.exe' | Select-Object -First 1
        if (-not $exe) { throw 'fluidsynth.exe not found in the archive' }
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        # Keep the exe's folder (with its DLLs) as tools\fluidsynth\bin.
        Copy-Item $exe.Directory.FullName (Join-Path $dest 'bin') -Recurse
        Write-Host "    -> $dest\bin\fluidsynth.exe"
    }
}
catch {
    Write-Host "    [!] $($_.Exception.Message)"
    exit 1
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
