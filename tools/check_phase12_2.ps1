$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pubspec = Join-Path $root 'pubspec.yaml'
if (!(Test-Path $pubspec)) { throw 'Run this script from the Flutter project where pubspec.yaml exists.' }
$pubspecText = Get-Content $pubspec -Raw
if ($pubspecText -notmatch '(?m)^name:\s*monopoly\s*$') {
  Write-Warning 'Package name differs from monopoly. Review any package:monopoly imports in the new tests.'
}
$required = @(
  'lib/game/ui/widgets/board_center_action.dart',
  'lib/game/ui/widgets/ownership_corner_badge.dart',
  'lib/game/ui/widgets/game_board_view.dart',
  'lib/game/ui/widgets/adaptive_board_panel.dart',
  'lib/game/ui/board_explorer_screen.dart',
  'lib/game/ui/game_board_screen.dart',
  'lib/game/ui/lan_board_screen.dart',
  'test/game/phase12_2_board_interactions_test.dart'
)
$missing = @($required | Where-Object { !(Test-Path (Join-Path $root $_)) })
if ($missing.Count -gt 0) {
  throw ('Missing source files: ' + ($missing -join ', '))
}
Write-Host 'Phase 12.2 source files found. Run flutter analyze and flutter test.' -ForegroundColor Green
