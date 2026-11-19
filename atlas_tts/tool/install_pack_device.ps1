# Side-loads a voice pack into a debug app's app_flutter documents dir on a
# connected Android device (interim until M5's CDN download manager exists;
# release builds are not debuggable so this needs a flutter debug build).
#
# Usage (from the atlas_tts/ directory):
#   powershell -ExecutionPolicy Bypass -File tool\install_pack_device.ps1
#     [-AppId com.example.atlas_tts_example]
#     [-Pack voices\vits-piper-en_US-amy-medium]
#
# Steps: push into the app's external files dir (adb-writable), then run-as
# copy into /data/data/<app>/app_flutter/<pack-root>, with verification.

param(
  [string]$AppId = "com.atlasapp.sk.atlas_app",
  [string]$Pack = ""  # default resolved below
)

$ErrorActionPreference = "Stop"
$atlasTtsDir = Split-Path $PSScriptRoot -Parent

if ($Pack -eq "") {
  # Default to any dir under voices/ holding an .onnx (the piper pack).
  $candidates = Get-ChildItem (Join-Path $atlasTtsDir "voices") -Directory -ErrorAction SilentlyContinue
  foreach ($c in $candidates) {
    if (Get-ChildItem $c.FullName -Filter "*.onnx") {
      $Pack = $c.FullName
      break
    }
  }
}
if ($Pack -eq "" -or -not (Test-Path $Pack)) {
  Write-Error "No voice pack found (searched voices\* for an .onnx). Run fetch_voice_pack.ps1 first."
}
$packId = Split-Path $Pack -Leaf
Write-Host "Pack: $Pack (id: $packId)"
Write-Host "App:  $AppId"
Write-Host ""

adb get-state 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Error "No device connected. Plug the device and retry."
}
adb wait-for-device

# Stage the pack where the app uid can read it. /sdcard/Android/data/<app>
# does NOT work here: shell-pushed files are unreadable to the app uid on
# scoped-storage ROMs (Android 11+). /data/local/tmp is world-readable, so
# run-as cp can pull from it directly.
$stageRoot = "/data/local/tmp/atlas_tts_pack_stage"
$stageNix = "$stageRoot/$packId"
adb shell "rm -rf $stageRoot"
adb shell "mkdir -p $stageNix"
Write-Host "Pushing ~64 MB over adb (a minute or two on USB)..."
adb push "$Pack/." $stageNix
if ($LASTEXITCODE -ne 0) { Write-Error "adb push failed." }

# Copy into the app's private documents dir (debuggable-only interface).
adb shell "run-as $AppId mkdir -p app_flutter/atlas_tts/voices/$packId"
adb shell "run-as $AppId cp -r $stageNix/. app_flutter/atlas_tts/voices/$packId/"
Write-Host "Verification (run-as listing):"
adb shell "run-as $AppId ls -la app_flutter/atlas_tts/voices/$packId"
Write-Host ""
Write-Host "Pack staged for $AppId. Launch the app; with a pack present the"
Write-Host "M4 gate activates NeuralTtsDriver on the next app start."
Write-Host "Staging copy cleanup:"
Write-Host "  adb shell rm -rf /data/local/tmp/atlas_tts_pack_stage"
