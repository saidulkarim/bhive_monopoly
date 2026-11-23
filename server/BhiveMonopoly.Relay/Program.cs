using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Collections.Concurrent;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<RelayHub>();
var app = builder.Build();

// Set BHIVE_ALLOWED_ORIGINS for public deployments, for example
// https://games.example.com. Leave empty only for local testing.
var webSockets = new WebSocketOptions
{
    KeepAliveInterval = TimeSpan.FromSeconds(20),
};
var allowedOrigins = (Environment.GetEnvironmentVariable("BHIVE_ALLOWED_ORIGINS") ?? "")
    .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
foreach (var origin in allowedOrigins)
    webSockets.AllowedOrigins.Add(origin);

app.UseWebSockets(webSockets);
app.MapGet("/health", () => Results.Ok(new { ok = true, service = "bhive-monopoly-relay", protocol = 1 }));
app.Map("/ws", async (HttpContext context, RelayHub hub) =>
{
    if (!context.WebSockets.IsWebSocketRequest)
    {
        context.Response.StatusCode = StatusCodes.Status400BadRequest;
        return;
    }
    using var socket = await context.WebSockets.AcceptWebSocketAsync();
    await hub.RunClientAsync(socket, context.RequestAborted);
});

app.Run();

/// <summary>
/// This is a room-scoped WebSocket relay, NOT a game engine. The Flutter
/// room creator owns the authoritative game state and validates all actions.
/// Relay peers cannot send host-to-guest messages or impersonate the host.
/// A host must stay online for its room to remain playable.
/// </summary>
sealed class RelayHub
{
    private const int MaxWireBytes = 256 * 1024;
    private static readonly Regex RoomCode = new("^[A-HJ-NP-Z2-9]{8}$", RegexOptions.Compiled);
    private readonly ConcurrentDictionary<string, Room> _rooms = new(StringComparer.Ordinal);

    public async Task RunClientAsync(WebSocket socket, CancellationToken disconnected)
    {
        var client = new Client(socket);
        try
        {
            while (socket.State == WebSocketState.Open && !disconnected.IsCancellationRequested)
            {
                var raw = await ReadMessageAsync(socket, disconnected);
                if (raw is null) break;
                await HandleAsync(client, raw);
            }
        }
        catch (OperationCanceledException) { }
        catch (WebSocketException) { }
        catch (IOException) { }
        catch (JsonException) { }
        finally
        {
            await RemoveAsync(client);
            client.SendGate.Dispose();
            if (socket.State == WebSocketState.Open)
            {
                try
                {
                    await socket.CloseAsync(WebSocketCloseStatus.NormalClosure,
                        "Disconnected", CancellationToken.None);
                }
                catch (WebSocketException) { }
                catch (ObjectDisposedException) { }
            }
        }
    }

    private static async Task<string?> ReadMessageAsync(WebSocket socket, CancellationToken cancellation)
    {
        var buffer = new byte[16 * 1024];
        using var stream = new MemoryStream();
        WebSocketReceiveResult frame;
        do
        {
            frame = await socket.ReceiveAsync(new ArraySegment<byte>(buffer), cancellation);
            if (frame.MessageType == WebSocketMessageType.Close) return null;
            if (frame.MessageType != WebSocketMessageType.Text)
                throw new JsonException("Only text messages are accepted.");
            if (stream.Length + frame.Count > MaxWireBytes)
                throw new JsonException("WebSocket message too large.");
            stream.Write(buffer, 0, frame.Count);
        } while (!frame.EndOfMessage);
        return new UTF8Encoding(false, true).GetString(stream.ToArray());
    }

    private async Task HandleAsync(Client client, string raw)
    {
        using var doc = JsonDocument.Parse(raw);
        var msg = doc.RootElement;
        if (msg.ValueKind != JsonValueKind.Object) return;
        var kind = GetString(msg, "kind");
        if (client.Room is null)
        {
            switch (kind)
            {
                case "create":
                    await CreateAsync(client, msg);
                    return;
                case "join":
                    await JoinAsync(client, msg);
                    return;
            }
            await ErrorAsync(client, "Create or join a room first.");
            return;
        }

        if (client.IsHost && kind == "to_peer")
        {
            var id = GetString(msg, "peer");
            var payload = GetString(msg, "payload");
            if (id is null || payload is null || Encoding.UTF8.GetByteCount(payload) > MaxWireBytes)
                return;
            Client? recipient;
            var room = client.Room!;
            lock (room.Sync) room.Guests.TryGetValue(id, out recipient);
            if (recipient != null) await recipient.SendAsync(payload);
            return;
        }

        if (!client.IsHost && kind == "to_host")
        {
            var payload = GetString(msg, "payload");
            if (payload is null || Encoding.UTF8.GetByteCount(payload) > MaxWireBytes)
                return;
            var room = client.Room;
            if (room != null)
            {
                await room.Host.SendJsonAsync(new
                {
                    kind = "peer_message", peer = client.Id, payload
                });
            }
            return;
        }
        await ErrorAsync(client, "This operation is not allowed for your role.");
    }

    private async Task CreateAsync(Client client, JsonElement msg)
    {
        var code = GetString(msg, "room");
        if (code is null || !RoomCode.IsMatch(code))
        {
            await ErrorAsync(client, "Invalid eight-character room code.");
            return;
        }
        var capacity = msg.TryGetProperty("capacity", out var value) &&
                       value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var count)
            ? count : 0;
        if (capacity < 2 || capacity > 6)
        {
            await ErrorAsync(client, "Room capacity must be 2–6 players.");
            return;
        }
        var room = new Room(code, capacity, client);
        if (!_rooms.TryAdd(code, room))
        {
            await ErrorAsync(client, "Room code already exists. Please try again.");
            return;
        }
        client.IsHost = true;
        client.Room = room;
        await client.SendJsonAsync(new { kind = "created", room = code });
    }

    private async Task JoinAsync(Client client, JsonElement msg)
    {
        var code = GetString(msg, "room");
        if (code is null || !_rooms.TryGetValue(code, out var room))
        {
            await ErrorAsync(client, "Room not found. Check the room code.");
            return;
        }
        lock (room.Sync)
        {
            if (room.Guests.Count < room.Capacity - 1 && room.Host.Socket.State == WebSocketState.Open)
            {
                client.Id = Guid.NewGuid().ToString("N");
                client.Room = room;
                room.Guests[client.Id] = client;
            }
        }
        if (client.Room is null)
        {
            await ErrorAsync(client, "Room full or host disconnected.");
            return;
        }
        await client.SendJsonAsync(new { kind = "joined", room = code });
    }

    private async Task RemoveAsync(Client client)
    {
        var room = client.Room;
        if (room is null) return;
        client.Room = null;
        if (client.IsHost)
        {
            // Atomic key+value removal protects a future room with the same code.
            ((ICollection<KeyValuePair<string, Room>>)_rooms).Remove(
                new KeyValuePair<string, Room>(room.Code, room));
            Client[] guests;
            lock (room.Sync)
            {
                guests = room.Guests.Values.ToArray();
                room.Guests.Clear();
                foreach (var guest in guests) guest.Room = null;
            }
            foreach (var guest in guests)
            {
                await guest.SendJsonAsync(new
                {
                    type = "error",
                    message = "The room host disconnected. This room is closed."
                });
                try
                {
                    if (guest.Socket.State == WebSocketState.Open)
                        await guest.Socket.CloseAsync(WebSocketCloseStatus.NormalClosure,
                            "Host left", CancellationToken.None);
                }
                catch (WebSocketException) { }
            }
        }
        else
        {
            lock (room.Sync) room.Guests.Remove(client.Id);
            await room.Host.SendJsonAsync(new { kind = "peer_left", peer = client.Id });
        }
    }

    private static string? GetString(JsonElement element, string key)
    {
        return element.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;
    }

    private static Task ErrorAsync(Client client, string message) =>
        client.SendJsonAsync(new { kind = "error", message });

    private sealed class Room(string code, int capacity, Client host)
    {
        public readonly object Sync = new();
        public readonly Dictionary<string, Client> Guests = new();
        public string Code { get; } = code;
        public int Capacity { get; } = capacity;
        public Client Host { get; } = host;
    }

    private sealed class Client(WebSocket socket)
    {
        public WebSocket Socket { get; } = socket;
        public SemaphoreSlim SendGate { get; } = new(1, 1);
        public string Id { get; set; } = "";
        public Room? Room { get; set; }
        public bool IsHost { get; set; }

        public Task SendJsonAsync(object data) => SendAsync(JsonSerializer.Serialize(data));

        public async Task SendAsync(string text)
        {
            if (Socket.State != WebSocketState.Open) return;
            try
            {
                await SendGate.WaitAsync();
                try
                {
                    if (Socket.State != WebSocketState.Open) return;
                    var bytes = Encoding.UTF8.GetBytes(text);
                    using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                    await Socket.SendAsync(new ArraySegment<byte>(bytes),
                        WebSocketMessageType.Text, true, timeout.Token);
                }
                finally { SendGate.Release(); }
            }
            catch (Exception ex) when (ex is WebSocketException or OperationCanceledException or ObjectDisposedException)
            {
                // A disconnect may race with a state broadcast. The socket's
                // receive loop will clean up room membership.
            }
        }
    }
}
