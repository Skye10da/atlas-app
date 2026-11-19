# Builds the M5 voice-pack CDN catalog (NTD §3.5) from the packs present
# under atlas_tts/voices/<pack-id>/, computing per-file sha256 + sizes.
#
# The catalog is what VoicePackCatalogService fetches; the publish script
# (publish_voice_packs.ps1) uploads it next to the pack files. Pack layout
# in the repo must be voices/<family-id>/<pack-id>/<file> — the app builds
# exactly those URLs from the family id in this document.
#
# Usage (from the atlas_tts/ directory):
#   powershell -ExecutionPolicy Bypass -File tool\build_voice_catalog.ps1
#     [-FamilyId piper-en_US-amy] [-OutFile build\voice_packs\catalog.json]
#
# Quality tiers map explicitly to pack dirs (deliberate, reviewed changes):
#   standard -> vits-piper-en_US-amy-medium   (RTF-validated on device)
#   compact  -> vits-piper-en_US-amy-low      (faster inference tier)

param(
  [string]$FamilyId = "piper-en_US-amy",
  [string]$OutFile = "build\voice_packs\catalog.json"
)

$ErrorActionPreference = "Stop"
$atlasTtsDir = Split-Path $PSScriptRoot -Parent

$flavors = @(
  @{ Quality = "standard"; PackDir = "vits-piper-en_US-amy-medium" },
  @{ Quality = "compact";  PackDir = "vits-piper-en_US-amy-low" }
)

$flavorJson = @()
foreach ($f in $flavors) {
  $packDir = Join-Path $atlasTtsDir ("voices\" + $f.PackDir)
  if (-not (Test-Path $packDir)) {
    Write-Warning "Pack missing, skipping flavor: $($f.PackDir). Run fetch_voice_pack.ps1."
    continue
  }

  # Every file under the pack becomes a catalog entry; nested paths
  # (espeak-ng-data/...) keep their forward-slash relative key — the
  # downloader creates intermediate directories for them.
  $files = [ordered]@{}
  $total = 0
  Get-ChildItem $packDir -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($packDir.Length + 1).Replace('\', '/')
    $sha = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToLower()
    $files[$rel] = [ordered]@{ sha256 = $sha }
    $total += $_.Length
  }
  if ($files.Count -eq 0) { Write-Warning "Empty pack dir: $packDir"; continue }

  $flavorJson += [ordered]@{
    quality = $f.Quality
    packId = $f.PackDir
    sizeBytes = $total
    modelFormatVersion = 1
    files = $files
  }
  Write-Host ("{0}: {1} files, {2} MB" -f $f.PackDir, $files.Count, [math]::Round($total / 1MB, 1))
}

if ($flavorJson.Count -eq 0) { Write-Error "No flavors collected; nothing to catalog." }

# Family-level metadata (previewUrl stays null for v1 — no sample clips yet).
$catalog = [ordered]@{
  schemaVersion = 1
  updatedUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  families = @(
    [ordered]@{
      id = $FamilyId
      name = "Amy"
      language = "en"
      locale = "en-US"
      gender = "female"
      previewUrl = $null
      flavors = $flavorJson
    }
  )
}

$outPath = Join-Path $atlasTtsDir $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null
$catalog | ConvertTo-Json -Depth 8 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Catalog written: $outPath ($((Get-Item $outPath).Length) bytes)"
