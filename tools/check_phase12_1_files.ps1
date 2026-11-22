$ErrorActionPreference = 'Stop'
$expected = @(
  'pubspec.yaml',
  'lib/game/engine/game_engine.dart',
  'lib/game/experience/board_camera_preset.dart',
  'lib/game/ui/board_explorer_screen.dart',
  'lib/game/ui/game_text.dart',
  'lib/game/ui/widgets/adaptive_board_panel.dart',
  'lib/game/ui/widgets/game_board_view.dart',
  'test/game/phase12_1_responsive_board_test.dart'
)
$missing = @()
foreach ($file in $expected) {
  if (Test-Path $file) {
    Write-Host "OK      $file" -ForegroundColor Green
  } else {
    Write-Host "MISSING $file" -ForegroundColor Red
    $missing += $file
  }
}
if ($missing.Count -gt 0) {
  Write-Host 'Some Phase 12.1 source files are missing. Extract the original Phase 12.1 source ZIP into the project root.' -ForegroundColor Yellow
  exit 1
}
$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -notmatch '(?m)^name:\s*bhive_monopoly\s*$') {
  Write-Host 'CHECK pubspec.yaml name: it must be bhive_monopoly to match test package imports.' -ForegroundColor Yellow
}
Write-Host 'All Phase 12.1 file paths are present.' -ForegroundColor Green
