param(
    [string]$Url = 'ws://127.0.0.1:5057/ws'
)

# Run while the Phase 14 relay server is running. No third-party tools required.
$ErrorActionPreference = 'Stop'

function Open-RelaySocket([string]$Address) {
    $socket = [System.Net.WebSockets.ClientWebSocket]::new()
    $socket.ConnectAsync([Uri]$Address, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    return $socket
}
function Send-RelayJson($socket, [string]$message) {
    $payload = [Text.Encoding]::UTF8.GetBytes($message)
    $buffer = [System.ArraySegment[byte]]::new($payload)
    $socket.SendAsync($buffer, [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
}
function Receive-RelayJson($socket) {
    $buffer = New-Object byte[] 262144
    $part = [System.ArraySegment[byte]]::new($buffer)
    $timeout = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(5))
    try {
        $result = $socket.ReceiveAsync($part, $timeout.Token).GetAwaiter().GetResult()
        if ($result.MessageType -ne [Net.WebSockets.WebSocketMessageType]::Text) { throw 'Expected a text reply.' }
        return [Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count) | ConvertFrom-Json
    }
    finally { $timeout.Dispose() }
}

$hostSocket = $null
$guestSocket = $null
try {
    $hostSocket = Open-RelaySocket $Url
    $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.ToCharArray()
    $code = -join (1..8 | ForEach-Object { Get-Random -InputObject $alphabet })
    Send-RelayJson $hostSocket ('{"kind":"create","room":"' + $code + '","capacity":4}')
    $created = Receive-RelayJson $hostSocket
    if ($created.kind -ne 'created') { throw "Create failed: $($created | ConvertTo-Json -Compress)" }

    $guestSocket = Open-RelaySocket $Url
    Send-RelayJson $guestSocket ('{"kind":"join","room":"' + $code + '"}')
    $joined = Receive-RelayJson $guestSocket
    if ($joined.kind -ne 'joined') { throw "Join failed: $($joined | ConvertTo-Json -Compress)" }

    $hello = '{"type":"hello","version":3,"name":"Guest","pin":"' + $code + '","avatarIndex":0}'
    $request = @{ kind = 'to_host'; payload = $hello } | ConvertTo-Json -Compress
    Send-RelayJson $guestSocket $request
    $forwarded = Receive-RelayJson $hostSocket
    if ($forwarded.kind -ne 'peer_message' -or $forwarded.payload -ne $hello) {
        throw 'The guest message did not reach the room host.'
    }

    $welcome = '{"type":"welcome","id":1,"token":"test-secret"}'
    Send-RelayJson $hostSocket (@{ kind = 'to_peer'; peer = $forwarded.peer; payload = $welcome } | ConvertTo-Json -Compress)
    $received = Receive-RelayJson $guestSocket
    if ($received.type -ne 'welcome' -or $received.id -ne 1) {
        throw 'The host reply did not reach the guest.'
    }
    Write-Host 'PASS: Relay Create -> Join -> Guest-to-Host -> Host-to-Guest' -ForegroundColor Green
}
finally {
    if ($null -ne $guestSocket) { $guestSocket.Dispose() }
    if ($null -ne $hostSocket) { $hostSocket.Dispose() }
}
