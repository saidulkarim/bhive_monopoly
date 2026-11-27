param(
    [Parameter(Mandatory=$true)][string]$PackageId,
    [Parameter(Mandatory=$true)][ValidateSet('start','end','sample')][string]$Stage,
    [string]$DeviceSerial,
    [string]$OutputDirectory = 'build/phase15_9g/android'
)
$ErrorActionPreference = 'Stop'
if ($PackageId -notmatch '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$') {
    throw 'Supply the actual Android applicationId from your project.'
}
$adb = (Get-Command adb -ErrorAction Stop).Source
$deviceArgs = @()
if ($DeviceSerial) { $deviceArgs = @('-s', $DeviceSerial) }
function Save-AdbOutput {
    param([string]$Name, [string[]]$CommandArgs)
    $output = & $adb @deviceArgs @CommandArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $Name : $output" }
    $output | Out-File -Encoding utf8 (Join-Path $folder "$Name.txt")
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$folder = Join-Path $OutputDirectory "$Stage-$stamp"
New-Item -ItemType Directory -Force $folder | Out-Null
Save-AdbOutput -Name 'battery' -CommandArgs @('shell','dumpsys','battery')
Save-AdbOutput -Name 'memory' -CommandArgs @('shell','dumpsys','meminfo',$PackageId)
Save-AdbOutput -Name 'graphics' -CommandArgs @('shell','dumpsys','gfxinfo',$PackageId)
Save-AdbOutput -Name 'process' -CommandArgs @('shell','pidof',$PackageId)
Save-AdbOutput -Name 'battery_stats' -CommandArgs @('shell','dumpsys','batterystats',$PackageId)
@{ timestamp = (Get-Date).ToString('o'); stage = $Stage; package = $PackageId; device = $DeviceSerial } |
    ConvertTo-Json | Out-File -Encoding utf8 (Join-Path $folder 'metadata.json')
Write-Host "Saved read-only Android diagnostics: $folder"
