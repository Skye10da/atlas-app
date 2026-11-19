# Uploads the M5 voice-pack CDN content to Hugging Face (free model hosting
# with real directory paths — the layout the app's downloader fetches).
#
# Repo layout produced (NTD §3.5):
#   catalog.json
#   voices/piper-en_US-amy/vits-piper-en_US-amy-medium/<files...>
#   voices/piper-en_US-amy/vits-piper-en_US-amy-low/<files...>
#
# The app's kVoicePackCdnBase points at
#   https://huggingface.co/<RepoId>/resolve/main
# so catalog + per-file URLs resolve with NO token for public repos.
#
# Prerequisites (one-time):
#   hf auth login            # a WRITE token from hf.co/settings/tokens
#
# Usage (from the atlas_tts/ directory):
#   powershell -ExecutionPolicy Bypass -File tool\publish_voice_packs.ps1
#     -RepoId <username>/atlas-voice-packs
#     [-CatalogJson build\voice_packs\catalog.json] [-VoicesDir voices]

param(
  [Parameter(Mandatory = $true)][string]$RepoId,
  [string]$CatalogJson = "build\voice_packs\catalog.json",
  [string]$VoicesDir = "voices"
)

$ErrorActionPreference = "Stop"
$atlasTtsDir = Split-Path $PSScriptRoot -Parent
$catalogPath = Join-Path $atlasTtsDir $CatalogJson
$voicesPath = Join-Path $atlasTtsDir $VoicesDir

if (-not (Test-Path $catalogPath)) {
  Write-Error "Catalog missing: $catalogPath. Run build_voice_catalog.ps1 first."
}

# Whoami fails when not logged in; catch that before a half-uploaded tree.
hf auth whoami 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Error "Not logged in. Run: hf auth login  (WRITE token from hf.co/settings/tokens)"
}

# The family layer of the URL comes from the catalog's family id; parse it
# so the upload path always matches what the app will request.
$catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
if ($catalog.schemaVersion -ne 1) {
  Write-Error "Unexpected catalog schemaVersion $($catalog.schemaVersion); regenerate with build_voice_catalog.ps1."
}
$familyId = $catalog.families[0].id
Write-Host "Catalog OK: family '$familyId', $($catalog.families[0].flavors.Count) flavor(s)."

# The repo already exists (hf 1.17 has no `hf repo view`; use the Python
# client's repo_exists — the CLI is built on it).
$existsCode = python -c "from huggingface_hub import HfApi`ntry:`n    HfApi().repo_exists('$RepoId')`n    raise SystemExit(0)`nexcept Exception:`n    raise SystemExit(1)"
if ($LASTEXITCODE -ne 0) {
  Write-Host "Creating public repo $RepoId ..."
  hf repo create $RepoId --repo-type model --public
  if ($LASTEXITCODE -ne 0) { Write-Error "hf repo create failed." }
} else {
  Write-Host "Repo exists: $RepoId"
}

# Upload catalog at the root, then each pack under voices/<family>/<packId>.
Write-Host "Uploading catalog.json..."
hf upload $RepoId $catalogPath catalog.json
if ($LASTEXITCODE -ne 0) { Write-Error "catalog upload failed." }

Get-ChildItem $voicesPath -Directory | ForEach-Object {
  $packId = $_.Name
  $target = "voices/$familyId/$packId"
  Write-Host "Uploading pack $packId -> $target ..."
  hf upload $RepoId $_.FullName $target
  if ($LASTEXITCODE -ne 0) { Write-Error "upload failed for $packId." }
}

Write-Host ""
Write-Host "Done. Set kVoicePackCdnBase to:"
Write-Host "  https://huggingface.co/$RepoId/resolve/main"
Write-Host "Verify in a browser:"
Write-Host "  https://huggingface.co/$RepoId/resolve/main/catalog.json"
