# bHiVE Monopoly — Phase 6 (incremental update for Phase 5.1)

This ZIP is a **source-code patch**, not a new Flutter application. Install it on top of the working **Phase 5.1 Font Settings** build. It preserves your saved Hadi/Nikosh/Exo2 font selection, local games, AI opponents, offline save/resume, Phase 5 LAN trading, and profile management.

## What's new

**1. Automatic discovery of nearby LAN rooms (Android and desktop).** A native host advertises its open room over UDP broadcast (port `8788`) every two seconds. Native joiners scan the same Wi-Fi/hotspot, tap a discovered room to fill its IP/port, and enter the existing **six-digit PIN** to join. Player counts refresh and old entries expire automatically. Host advertisements stop after match start. **Manual IP joining remains available**, including in Flutter Web (browsers cannot listen on UDP sockets).

**2. Shared player avatars.** The lobby shows six selectable preset icons. Your existing app profile avatar index is carried into LAN game setup. An optional **Share my profile photo with LAN players** toggle transmits a JPEG/PNG image to the room only if you opt in and the file is <= 64 KiB. Oversized or unsupported photos fall back to the preset icon. Other players see synced avatars in the lobby and in the game board player list. Avatars are not used as identity credentials; the existing server-authoritative room PIN and per-client reconnect tokens remain in place.

**3. Multi-property LAN trading.** The trade dialog now uses multi-select chips for both sides of a deal, alongside cash amounts. The existing Phase 5 `GameEngine.validateTrade` and host-side acceptance flow validate the complete offer. Mortgaged/developed properties remain ineligible as before. Recipients can accept or decline, and the proposer can cancel.

## Replace/add files

Extract the ZIP at the **Flutter project root**, preserving paths. Back up your existing project first.

| Action | Path |
|---|---|
| Replace | `lib/game/network/lan_room_controller.dart` |
| Replace | `lib/game/ui/lan_lobby_screen.dart` |
| Replace | `lib/game/ui/lan_board_screen.dart` |
| Replace | `lib/game/ui/game_setup_screen.dart` |
| Replace | `lib/ui/screens/home_screen.dart` |
| Add | `lib/game/network/lan_discovery.dart` |
| Add | `lib/game/network/lan_discovery_native.dart` |
| Add | `lib/game/network/lan_discovery_stub.dart` |
| Add | `lib/game/network/lan_avatar_codec.dart` |
| Add | `lib/game/ui/widgets/lan_avatar_badge.dart` |
| Add | `test/game/phase6_*.dart` (four test files) |

Your existing `main.dart`, `pubspec.yaml`, `assets/fonts`, `lib/core/fonts`, `lib/game/engine`, `lib/game/persistence`, and other Phase 5 files are **not replaced**. No new Dart packages or font files are required. This patch assumes your Phase 4 network dependencies and permissions are already in place.

## Run (VS Code PowerShell)

```powershell
flutter pub get
dart format lib/game/network lib/game/ui lib/ui/screens/home_screen.dart test/game
flutter analyze
flutter test test/game/phase6_discovery_test.dart
flutter test test/game/phase6_avatar_test.dart
flutter test test/game/phase6_multi_property_trade_test.dart
flutter test test/game/phase6_lan_avatar_integration_test.dart
flutter run
```

For Flutter Web: `flutter run -d chrome`.


## LAN network details

- Host: Android/desktop uses TCP **8787** for gameplay and sends UDP **8788** broadcasts for lobby discovery.
- Guest: Android/desktop listens for UDP **8788** and connects to the selected host via TCP **8787**. The PIN is **never present** in a UDP announcement.
- Web: joins using the host IPv4 + PIN, not automatic discovery. The host cannot be a browser (as in Phase 4/5).
- Networks that block UDP broadcast, isolate Wi-Fi clients, or apply firewall rules may hide nearby rooms. The **manual-IP workflow still works** if the TCP connection itself is allowed. Windows Firewall may prompt for permission for both TCP and UDP.
- The host must stay open; this update does not add Internet-hosted matchmaking or an external relay server.
- Local LAN WebSockets are **not encrypted** (`ws://`) in the existing architecture. Do not opt into sharing a photo on an untrusted Wi-Fi network. HTTPS browser deployments may refuse insecure `ws://` connections (mixed content).
- Phase 6 increments `LanRoomController.protocolVersion` from **2 to 3**. **All participants must update to Phase 6**. Earlier versions will be rejected as incompatible.

## Verify with 2 devices

1. Install Phase 6 on two Android devices and connect them to the same Wi-Fi/hotspot.
2. Device A: **Start Game → Wi-Fi/LAN Multiplayer → Host game → Create Room**. Note the IP and PIN.
3. Device B: **Join game**. Wait for A to appear under **Nearby Wi-Fi rooms**, tap **Select**, enter A's PIN, and join.
4. If no room appears, type A's IP and PIN manually; check client isolation and UDP port 8788.
5. On either device, pick a preset avatar. Optionally opt into photo sharing with a sufficiently small JPEG/PNG profile picture. Verify avatars in both lobbies and the board after the host starts.
6. On the active player's turn, tap **Offer Trade**. Select multiple eligible properties, submit, and approve on the recipient's device. Confirm both players see the identical ownership/cash state.
7. Confirm fonts in the Home screen and game screens still follow **Font Settings**.

## Scope and limitations

This is a production-oriented **integration patch** with Dart tests; it is **not a Flutter-tested release**. The ZIP was structurally checked but a Flutter SDK, emulator, and two LAN-connected devices are unavailable in the packaging environment. Run `flutter analyze` and tests locally before publishing. The photo transfer currently preserves images *only if they already fit the 64 KiB limit*; it does not compress camera images automatically. UDP room scanning is best-effort, not guaranteed on all router/hotspot configurations.

**Next candidate milestone (Phase 7):** compressed avatar thumbnails, sound settings and real dice/coin audio assets, improved animated 3D pieces, and LAN reconnection QA.
