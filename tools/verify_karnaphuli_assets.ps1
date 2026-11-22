# Run from Flutter project root. Read-only asset checks.
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$pubspec = Join-Path $root 'pubspec.yaml'
$font = Join-Path $root 'assets/fonts/KarnaphuliMJ.ttf'
if (-not (Test-Path $pubspec)) { throw 'pubspec.yaml not found. Run in project root.' }
if (-not (Test-Path $font)) { throw 'Missing assets/fonts/KarnaphuliMJ.ttf' }
$content = Get-Content $pubspec -Raw -Encoding UTF8
if ($content -notmatch '(?m)^\s*-\s*family:\s*Karnaphuli\s*$') {
    throw 'Karnaphuli family is not registered in pubspec.yaml.'
}
if ($content -notmatch '(?m)^\s*-\s*asset:\s*assets/fonts/KarnaphuliMJ\.ttf\s*$') {
    throw 'The KarnaphuliMJ.ttf asset entry is missing in pubspec.yaml.'
}
Write-Host 'PASS: Karnaphuli is registered and the TTF file exists.' -ForegroundColor Green
Write-Host 'Next: flutter pub get; flutter test test/game/game_typography_test.dart'
