# Fetches the native dependencies atlas_tts binaries (gitignored) need and
# extracts them under atlas_tts/:
#   - native_deps/: sherpa-onnx v1.13.8 win-x64 shared runtime + the C API
#     header (host test/probe builds)
#   - voices/vits-piper-en_US-amy-medium/: the bundled default voice pack
#
# Pinned versions — bump deliberately (see NTD: v2.x changed the
# phonemization model, so re-pinning needs core work).
#
# Usage: powershell -ExecutionPolicy Bypass -File tool\fetch_voice_pack.ps1
#        (run from the atlas_tts/ directory)

$ErrorActionPreference = 'Stop'
$root = Get-Location

# Resolve the atlas_tts dir whether invoked from there or from a subdir.
if ($root.Name -ne 'atlas_tts') {
  Write-Error 'Run from the atlas_tts/ directory.'
}

$sherpaVersion = 'v1.13.8'
$results = @()

# --- 1. sherpa-onnx host runtime (win-x64, MD runtime, import libs) ---------
$sherpaDir = Join-Path $root 'native_deps'
New-Item -ItemType Directory -Force -Path $sherpaDir | Out-Null

$runtimeArchive = 'sherpa-win32.tar.bz2'
if (-not (Test-Path (Join-Path $sherpaDir 'sherpa-onnx-v1.13.8-win-x64-shared-MD-Release-lib'))) {
  Write-Host 'Fetching sherpa-onnx win-x64 shared runtime...'
  $url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/$sherpaVersion/sherpa-onnx-v1.13.8-win-x64-shared-MD-Release-lib.tar.bz2"
  $archive = Join-Path $sherpaDir $runtimeArchive
  Invoke-WebRequest -Uri $url -OutFile $archive
  tar -xjf $archive -C $sherpaDir
  Remove-Item $archive
  $results += 'sherpa-onnx runtime'
} else {
  Write-Host 'sherpa-onnx runtime already present.'
}

# --- 2. C API header --------------------------------------------------------
$header = Join-Path $sherpaDir 'sherpa-onnx\sherpa-onnx\c-api\c-api.h'
if (-not (Test-Path $header)) {
  Write-Host 'Fetching sherpa-onnx C API header...'
  New-Item -ItemType Directory -Force -Path (Split-Path $header) | Out-Null
  $url = "https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/$sherpaVersion/sherpa-onnx/c-api/c-api.h"
  Invoke-WebRequest -Uri $url -OutFile $header
  $results += 'c-api.h'
} else {
  Write-Host 'C API header already present.'
}

# --- 3. Voice packs (published to HF by publish_voice_packs.ps1) -----------
# medium = the device-validated Standard tier; low = the Compact tier
# (faster inference, similar size for amy — see build_voice_catalog.ps1).
$packs = @(
  @{ Dir = 'vits-piper-en_US-amy-medium'; Url = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-amy-medium.tar.bz2' },
  @{ Dir = 'vits-piper-en_US-amy-low'; Url = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-amy-low.tar.bz2' }
)
$packFetched = @()
foreach ($pack in $packs) {
  $packDir = Join-Path $root ("voices\" + $pack.Dir)
  if (-not (Test-Path (Join-Path $packDir '*.onnx'))) {
    Write-Host ("Fetching voice pack ({0})..." -f $pack.Dir)
    $archive = Join-Path $sherpaDir ($pack.Dir + '.tar.bz2')
    Invoke-WebRequest -Uri $pack.Url -OutFile $archive
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'voices') | Out-Null
    tar -xjf $archive -C (Join-Path $root 'voices')
    Remove-Item $archive
    $packFetched += $pack.Dir
  }
}
if ($packFetched.Count -gt 0) { $results += ("voice packs: " + ($packFetched -join ', ')) }

# --- 4. sherpa-onnx Android runtime (device builds; M3 remainder) -----------
# Layout consumed by the plugin's gradle build: native_deps/android/jniLibs/
# <abi>/libsherpa-onnx-c-api.so + libonnxruntime.so. The cxx-api and jni
# libraries from the release tarball are dropped: libsherpa-onnx-c-api.so
# statically contains them (verified via NEEDED entries) and the jni wrapper
# is unnecessary for the FFI plugin.
$androidDir = Join-Path $sherpaDir 'android\jniLibs'
if (-not (Test-Path (Join-Path $androidDir 'arm64-v8a\libsherpa-onnx-c-api.so'))) {
  Write-Host 'Fetching sherpa-onnx Android runtime...'
  $url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/$sherpaVersion/sherpa-onnx-$sherpaVersion-android.tar.bz2"
  $archive = Join-Path $sherpaDir 'sherpa-android.tar.bz2'
  Invoke-WebRequest -Uri $url -OutFile $archive
  New-Item -ItemType Directory -Force -Path (Join-Path $sherpaDir 'android') |
    Out-Null
  tar -xjf $archive -C (Join-Path $sherpaDir 'android')
  Remove-Item $archive
  Get-ChildItem -Recurse $androidDir -Filter 'libsherpa-onnx-cxx-api.so' |
    Remove-Item -Force
  Get-ChildItem -Recurse $androidDir -Filter 'libsherpa-onnx-jni.so' |
    Remove-Item -Force
  Get-ChildItem -Recurse $androidDir -Filter 'README.md' | Remove-Item -Force
  $results += 'sherpa-onnx Android runtime'
} else {
  Write-Host 'sherpa-onnx Android runtime already present.'
}

if ($results.Count -eq 0) {
  Write-Host 'Everything already fetched. Nothing to do.'
} else {
  Write-Host ("Fetched: " + ($results -join ', '))
}
Write-Host "Done. Runtime: $sherpaDir  Voice: $packDir"
