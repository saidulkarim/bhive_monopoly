param([switch]$Extended)
$ErrorActionPreference = 'Stop'
$folder = 'build/phase15_9g'
New-Item -ItemType Directory -Force $folder | Out-Null
$mode = if ($Extended) { 'extended' } else { 'smoke' }
$log = Join-Path $folder "$mode-$(Get-Date -Format yyyyMMdd-HHmmss).log"
$testArgs = @('test','--reporter','expanded','--concurrency=1', 'test/game/phase15_9g_soak_test.dart','test/game/phase15_9g_resource_soak_test.dart')
if ($Extended) { $testArgs += '--dart-define=BHIVE_EXTENDED_SOAK=true' }
& flutter @testArgs 2>&1 | Tee-Object -FilePath $log
$code = $LASTEXITCODE
Write-Host "Log: $log; exit code: $code"
exit $code
