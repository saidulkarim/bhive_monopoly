# bHiVE Monopoly Phase 4 - Optional configuration helper.
# Run from the Flutter project root after extracting the ZIP:
#   powershell -ExecutionPolicy Bypass -File .\tools\configure_phase4.ps1
# Only pubspec.yaml and AndroidManifest.xml are edited; backups are created.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Pubspec = Join-Path $Root 'pubspec.yaml'
$Manifest = Join-Path $Root 'android\app\src\main\AndroidManifest.xml'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (!(Test-Path $Pubspec)) {
  throw "pubspec.yaml not found in '$Root'. Extract ZIP at your Flutter project root."
}

$Text = [System.IO.File]::ReadAllText($Pubspec)
if ($Text -notmatch '(?m)^\s{2}web_socket_channel\s*:') {
  if ($Text -notmatch '(?m)^dependencies\s*:\s*$') {
    throw "Could not find dependencies: section in pubspec.yaml; please add web_socket_channel: ^3.0.1 manually."
  }
  Copy-Item $Pubspec "$Pubspec.phase4.bak" -Force
  $nl = if ($Text.Contains("`r`n")) {"`r`n"} else {"`n"}
  $DependencyRegex = [regex]::new('(?m)^(dependencies[ \t]*:[ \t]*)$')
  $Text = $DependencyRegex.Replace($Text, ('$1' + $nl + '  web_socket_channel: ^3.0.1'), 1)
  [System.IO.File]::WriteAllText($Pubspec, $Text, $Utf8NoBom)
  Write-Host '[OK] Added web_socket_channel dependency.' -ForegroundColor Green
} else {
  Write-Host '[OK] web_socket_channel dependency already present.' -ForegroundColor Green
}

if (!(Test-Path $Manifest)) {
  Write-Warning 'AndroidManifest.xml not found. Skipping Android changes.'
  exit 0
}
$Xml = [System.IO.File]::ReadAllText($Manifest)
$Original = $Xml
$nl = if ($Xml.Contains("`r`n")) {"`r`n"} else {"`n"}
foreach ($Permission in @('INTERNET', 'ACCESS_WIFI_STATE', 'ACCESS_NETWORK_STATE')) {
  if ($Xml -notmatch ('android\.permission\.' + $Permission + '\b')) {
    $Start = $Xml.IndexOf('<manifest')
    if ($Start -lt 0) { throw 'Could not find <manifest> tag.' }
    $End = $Xml.IndexOf('>', $Start)
    if ($End -lt 0) { throw 'Could not find the end of <manifest> tag.' }
    $Add = $nl + '    <uses-permission android:name="android.permission.' + $Permission + '" />'
    $Xml = $Xml.Insert($End + 1, $Add)
  }
}
if ($Xml -notmatch 'android:usesCleartextTraffic\s*=') {
  $ApplicationRegex = [regex]::new('<application(?=\s|>)')
  $Xml = $ApplicationRegex.Replace($Xml, '<application android:usesCleartextTraffic="true"', 1)
}
if ($Xml -ne $Original) {
  Copy-Item $Manifest "$Manifest.phase4.bak" -Force
  [System.IO.File]::WriteAllText($Manifest, $Xml, $Utf8NoBom)
  Write-Host '[OK] Added Android network permissions / cleartext flag.' -ForegroundColor Green
} else {
  Write-Host '[OK] Android network configuration already present.' -ForegroundColor Green
}
Write-Host 'Now run: flutter pub get; dart format lib/game test/game; flutter analyze; flutter test' -ForegroundColor Cyan
