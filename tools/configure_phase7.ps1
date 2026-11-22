$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
$pubspec = Join-Path $root 'pubspec.yaml'
if (-not (Test-Path $pubspec)) { throw 'Run this script from an extracted patch at the Flutter project root. pubspec.yaml is missing.' }
if (-not (Test-Path (Join-Path $root 'assets/audio/dice_roll.wav'))) { throw 'Phase 7 audio assets were not extracted. Copy the complete ZIP first.' }

$content = Get-Content -Path $pubspec -Raw -Encoding UTF8
$lineEnding = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
if ($content -notmatch '(?m)^flutter:\s*$') { throw 'No Flutter section in pubspec.yaml. Review manually.' }
if ($content -notmatch '(?m)^\s{4}-\s*assets/audio/\s*$') {
  Copy-Item $pubspec "$pubspec.phase7.bak" -Force
  if ($content -match '(?m)^  assets:\s*$') {
    $content = [regex]::Replace($content, '(?m)^(  assets:\s*)$',
      { param($m) $m.Groups[1].Value.TrimEnd() + $lineEnding + '    - assets/audio/' })
  } else {
    $content = [regex]::Replace($content, '(?m)^flutter:\s*$',
      { param($m) 'flutter:' + $lineEnding + '  assets:' + $lineEnding + '    - assets/audio/' })
  }
  [System.IO.File]::WriteAllText($pubspec, $content, [System.Text.UTF8Encoding]::new($false))
  Write-Host 'Added assets/audio/ to pubspec.yaml; backup saved.'
} else { Write-Host 'Audio asset directory already configured.' }

Write-Host 'Adding two dependencies: audioplayers and image'
flutter pub add 'audioplayers:^6.1.0' 'image:^4.5.4'
if ($LASTEXITCODE -ne 0) { throw 'Flutter package setup failed; check your SDK and network. See README.md.' }
Write-Host 'Phase 7 configuration completed.'
