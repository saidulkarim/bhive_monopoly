# bHiVE Monopoly Phase 12 - non-destructive validation for Windows / VS Code.
# Examples:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\phase12_release_check.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\phase12_release_check.ps1 -FullTests -BuildWeb
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\phase12_release_check.ps1 -FullTests -BuildAndroid
param(
  [switch]$FullTests,
  [switch]$BuildWeb,
  [switch]$BuildAndroid
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $projectRoot

if (-not (Test-Path '.\pubspec.yaml')) {
  throw 'Run this script from inside the extracted bHiVE Monopoly Flutter project.'
}

function Invoke-Checked([string]$Description, [string]$Command, [string[]]$Arguments) {
  Write-Host "`n== $Description ==" -ForegroundColor Cyan
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Description failed (exit code $LASTEXITCODE)."
  }
}

Write-Host 'bHiVE Monopoly - Phase 12 quality gate' -ForegroundColor Yellow
Write-Host "Project: $projectRoot"
Write-Host 'Note: this script does not modify code or signing configuration.'

# Existence checks reveal common mistakes when merging phase ZIPs.
$required = @(
  'lib\game\validation\game_snapshot_validator.dart',
  'lib\game\network\lan_game_codec.dart',
  'lib\game\persistence\offline_game_store.dart',
  'test\game\phase12_snapshot_integrity_test.dart',
  'test\game\phase12_save_recovery_test.dart'
)
foreach ($relative in $required) {
  if (-not (Test-Path (Join-Path $projectRoot $relative))) {
    throw "Missing Phase 12 file: $relative"
  }
}

# These assets caused a missing-bundle test failure during Phase 8.
$modelNames = @('gold_car', 'pearl_yacht', 'royal_crown', 'sky_rocket', 'pearl_dice')
foreach ($model in $modelNames) {
  $modelPath = Join-Path $projectRoot "assets\models\$model.glb"
  if (-not (Test-Path $modelPath)) {
    throw "Missing 3D model asset: assets/models/$model.glb"
  }
}
if (-not (Select-String -Path '.\pubspec.yaml' -Pattern 'assets/models/' -Quiet)) {
  throw 'pubspec.yaml does not register assets/models/. See Phase 8 setup.'
}

Invoke-Checked 'Flutter version' 'flutter' @('--version')
Invoke-Checked 'Flutter doctor' 'flutter' @('doctor', '-v')
Invoke-Checked 'Resolve dependencies' 'flutter' @('pub', 'get')
Invoke-Checked 'Static analysis' 'flutter' @('analyze')
Invoke-Checked 'Phase 12 snapshot tests' 'flutter' @('test', 'test/game/phase12_snapshot_integrity_test.dart')
Invoke-Checked 'Phase 12 save recovery tests' 'flutter' @('test', 'test/game/phase12_save_recovery_test.dart')
Invoke-Checked 'Phase 12 LAN event tests' 'flutter' @('test', 'test/game/phase12_lan_event_preflight_test.dart')

if ($FullTests) {
  Invoke-Checked 'Full game regression suite' 'flutter' @('test', 'test/game/')
}
if ($BuildWeb) {
  Invoke-Checked 'Release web build' 'flutter' @('build', 'web', '--release')
}
if ($BuildAndroid) {
  Invoke-Checked 'Release Android APK build' 'flutter' @('build', 'apk', '--release')
  Write-Warning 'A successful APK build does not confirm Play Store signing or policy compliance.'
}

Write-Host "`nPhase 12 checks completed successfully." -ForegroundColor Green
Write-Host 'Still test real Android devices, Chrome, and 2+ devices on a LAN before release.'
