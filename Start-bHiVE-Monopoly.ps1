# bHiVE Monopoly - one-command local development launcher (Phase 14.0.2)
# Place this script in the Flutter project root, beside pubspec.yaml.
# Starts the ASP.NET Core relay first, then launches Flutter Web.
# The relay stays running in its own console after Flutter quits.
[CmdletBinding()]
param(
    [ValidateRange(1, 65535)][int]$RelayPort = 5057,
    [ValidateRange(1, 65535)][int]$WebPort = 18080
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$relayProject = Join-Path $projectRoot 'server\BhiveMonopoly.Relay\BhiveMonopoly.Relay.csproj'
$pubspec = Join-Path $projectRoot 'pubspec.yaml'
$relayHealth = "http://127.0.0.1:$RelayPort/health"
$webAddress = "http://127.0.0.1:$WebPort"

if (-not (Test-Path -LiteralPath $pubspec)) {
    throw "Place Start-bHiVE-Monopoly.ps1 in your Flutter project's root (pubspec.yaml missing)."
}
if (-not (Test-Path -LiteralPath $relayProject)) {
    throw "Relay project not found: $relayProject. Install Phase 14.0 first."
}
foreach ($commandName in @('dotnet', 'flutter')) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "Required command '$commandName' is not installed or not on PATH."
    }
}
if ($RelayPort -eq $WebPort) {
    throw 'The relay and Flutter Web must use different ports.'
}

function Test-BhiveRelay {
    try {
        $result = Invoke-RestMethod -Uri $relayHealth -TimeoutSec 2 -ErrorAction Stop
        return ($result.ok -eq $true -and $result.service -eq 'bhive-monopoly-relay')
    } catch {
        return $false
    }
}

function Assert-FreePort([int]$port) {
    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new(
            [System.Net.IPAddress]::Loopback, $port)
        $listener.Start()
    } catch {
        throw "Port $port cannot be bound. Close its existing service, or choose another port. $($_.Exception.Message)"
    } finally {
        if ($null -ne $listener) { $listener.Stop() }
    }
}

Set-Location -LiteralPath $projectRoot

if (Test-BhiveRelay) {
    Write-Host "[OK] Existing bHiVE relay available at $relayHealth" -ForegroundColor Green
} else {
    Assert-FreePort -port $RelayPort
    Write-Host "[START] ASP.NET Core multiplayer relay on port $RelayPort" -ForegroundColor Cyan

    # A separate console keeps relay logs visible and allows it to remain
    # available for phones and other players when Flutter is stopped.
    $relayArgs = "run --project `"$relayProject`" --urls http://0.0.0.0:$RelayPort"
    $relayProcess = Start-Process -FilePath 'dotnet' -ArgumentList $relayArgs `
        -WorkingDirectory (Split-Path -Parent $relayProject) -PassThru

    $ready = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        if (Test-BhiveRelay) {
            $ready = $true
            break
        }
        if ($relayProcess.HasExited) { break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) {
        throw "Relay did not become healthy at $relayHealth. Inspect the relay terminal for errors."
    }
    Write-Host "[OK] Relay is healthy: $relayHealth" -ForegroundColor Green
}

Write-Host "" 
Write-Host '================ bHiVE Monopoly ================' -ForegroundColor Cyan
Write-Host "Web app:        $webAddress"
Write-Host "Relay endpoint: ws://192.168.1.107:$RelayPort/ws  (LAN example for this PC)"
Write-Host "Local relay:    ws://127.0.0.1:$RelayPort/ws"
Write-Host 'Use your current PC LAN IP if it has changed.'
Write-Host 'Press q in Flutter to stop the web server. Relay continues separately.'
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ''

# The Flutter server stays in this terminal and supports normal keyboard controls.
& flutter run -d web-server --web-hostname=127.0.0.1 --web-port=$WebPort
