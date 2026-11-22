# bHiVE Monopoly Phase 8 installer - run from project root.
# Non-destructive: creates timestamped backups before editing existing files.
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$pubspec = Join-Path $root 'pubspec.yaml'
$webIndex = Join-Path $root 'web\index.html'
if (-not (Test-Path $pubspec)) { throw 'Run this command from the Flutter project root (pubspec.yaml not found).' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
function Backup([string]$file) {
  Copy-Item -LiteralPath $file -Destination "$file.phase8-$stamp.bak" -Force
}
# Add asset directory beneath flutter/assets without touching registered fonts/audio.
$p = [System.IO.File]::ReadAllText($pubspec)
if ($p -notmatch '(?m)^\s+-\s+assets/models/\s*$') {
  if ($p -match '(?m)^  assets:\s*$') {
    Backup $pubspec
    $p = ([regex]::new('(?m)^(  assets:[ \t]*)$')).Replace($p, '$1' + "`r`n    - assets/models/", 1)
  } elseif ($p -match '(?m)^  uses-material-design:\s*(true|false)\s*$') {
    Backup $pubspec
    $p = ([regex]::new('(?m)^(  uses-material-design:[ \t]*(true|false)[ \t]*)$')).Replace($p, '$1' + "`r`n  assets:`r`n    - assets/models/", 1)
  } else {
    Write-Warning 'Could not safely locate flutter assets section in pubspec.yaml; add assets/models/ manually.'
  }
  [System.IO.File]::WriteAllText($pubspec, $p, [System.Text.UTF8Encoding]::new($false))
}
# Package uses bundled model-viewer JS (not an external CDN).
if (Test-Path $webIndex) {
  $html = [System.IO.File]::ReadAllText($webIndex)
  if ($html -notmatch 'model_viewer_plus/assets/model-viewer.min.js') {
    if ($html -match '</head>') {
      Backup $webIndex
      $scriptTag = '  <script type="module" src="./assets/packages/model_viewer_plus/assets/model-viewer.min.js" defer></script>'
      $html = $html.Replace('</head>', "$scriptTag`r`n</head>")
      [System.IO.File]::WriteAllText($webIndex, $html, [System.Text.UTF8Encoding]::new($false))
    } else { Write-Warning 'web/index.html has no </head>; add model-viewer script manually.' }
  }
}
# Intentionally DO NOT edit Android network settings: LAN may already rely on
# custom cleartext/WebSocket rules. See README only if the WebView model fails.
Write-Host 'Android network policy unchanged to preserve LAN multiplayer.'
Write-Host 'Installing 3D viewer package...'
flutter pub add 'model_viewer_plus:^1.10.0'
if ($LASTEXITCODE -ne 0) { throw 'flutter pub add failed. Check the package version / SDK requirements.' }
Write-Host 'Phase 8 configuration complete. Run flutter analyze and flutter test.'
