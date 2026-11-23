import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/ui/app_notices.dart';
import 'package:flutter/services.dart';

import '../network/lan_room_controller.dart';
import '../network/relay_protocol.dart';
import '../network/bluetooth_game_bridge.dart';
import '../network/lan_discovery.dart';
import '../network/lan_avatar_codec.dart';
import '../network/lan_avatar_compressor.dart';
import 'widgets/lan_avatar_badge.dart';
import 'game_text.dart';
import 'game_typography.dart';
import 'lan_board_screen.dart';
import 'widgets/game_board_view.dart';
import '../experience/player_palette.dart';

/// Local Wi-Fi or server-relayed room; both Android and Web may host.
class LanLobbyScreen extends StatefulWidget {
  const LanLobbyScreen({
    super.key,
    required this.playerName,
    required this.languageCode,
    this.avatarIndex = 0,
    this.avatarBytes,
  });

  final String playerName;
  final String languageCode;
  final int avatarIndex;
  final Uint8List? avatarBytes;

  @override
  State<LanLobbyScreen> createState() => _LanLobbyScreenState();
}

class _LanLobbyScreenState extends State<LanLobbyScreen> {
  late final GameText t = GameText(widget.languageCode);
  late final TextEditingController _name = TextEditingController(
    text: widget.playerName,
  );
  final TextEditingController _ip = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _bluetoothAddress = TextEditingController();
  List<BluetoothGameDevice> _pairedBluetoothDevices =
      const <BluetoothGameDevice>[];
  bool _loadingBluetoothDevices = false;
  late final TextEditingController _relayUrl = TextEditingController(
    text: _defaultRelayUrl(),
  );
  bool _onlineMode = kIsWeb;
  bool _bluetoothMode = false;
  bool _hostMode = true;
  bool _loading = false;
  bool _handedOff = false;
  int _maxPlayers = 4;
  int _shownErrorRevision = 0;
  LanRoomController? _room;
  final LanDiscoveryService _discovery = LanDiscoveryService();
  int _avatarIndex = 0;
  bool _sharePhoto = false;

  static String _defaultRelayUrl() {
    if (!kIsWeb) return '';
    final origin = Uri.base;
    if (origin.host == 'localhost' || origin.host == '127.0.0.1') {
      return 'ws://${origin.host}:5057/ws';
    }
    final protocol = origin.scheme == 'https' ? 'wss' : 'ws';
    return '$protocol://${origin.authority}/bhive-relay/ws';
  }

  void _changeNetworkMode(bool online) {
    if (_onlineMode == online && !_bluetoothMode) return;
    unawaited(_discovery.stopBrowsing());
    setState(() {
      _onlineMode = online;
      _bluetoothMode = false;
      _hostMode = online || !kIsWeb;
      _pin.clear();
    });
  }

  void _changeBluetoothMode() {
    if (_bluetoothMode) return;
    unawaited(_discovery.stopBrowsing());
    setState(() {
      _onlineMode = false;
      _bluetoothMode = true;
      _hostMode = true;
      _pin.clear();
    });
    unawaited(_refreshBluetoothDevices());
  }

  Future<void> _refreshBluetoothDevices() async {
    if (!BluetoothGameBridge.isSupported || _loadingBluetoothDevices) return;
    setState(() => _loadingBluetoothDevices = true);
    try {
      final devices = await BluetoothGameBridge.instance.pairedDevices();
      if (!mounted) return;
      setState(() => _pairedBluetoothDevices = devices);
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _loadingBluetoothDevices = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _avatarIndex = LanAvatarCodec.preset(widget.avatarIndex);
    _discovery.addListener(_onDiscoveryChange);
    if (kIsWeb) return;
    // Host mode is selected initially on native devices. The scanner starts
    // when the player chooses Join Game.
  }

  void _onDiscoveryChange() {
    if (mounted) setState(() {});
  }

  void _changeMode(bool hosting) {
    setState(() => _hostMode = hosting);
    if (hosting || _onlineMode || _bluetoothMode) {
      unawaited(_discovery.stopBrowsing());
    } else if (!kIsWeb) {
      unawaited(
        _discovery.startBrowsing(protocol: LanRoomController.protocolVersion),
      );
    }
  }

  @override
  void dispose() {
    final room = _room;
    room?.removeListener(_onRoomChange);
    if (!_handedOff && room != null) unawaited(room.shutdown());
    _discovery.removeListener(_onDiscoveryChange);
    unawaited(_discovery.close());
    _name.dispose();
    _ip.dispose();
    _pin.dispose();
    _bluetoothAddress.dispose();
    _relayUrl.dispose();
    super.dispose();
  }

  void _onRoomChange() {
    if (!mounted) return;
    final room = _room;
    if (room == null) return;
    if (room.errorRevision > _shownErrorRevision) {
      _shownErrorRevision = room.errorRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || room.lastError == null) return;
        AppNotices.of(context).showSnackBar(
          SnackBar(
            content: Text(room.lastError!),
            backgroundColor: const Color(0xFF9C423C),
          ),
        );
      });
    }
    if (room.started && !_handedOff) {
      _handedOff = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => GameTypography(
              languageCode: widget.languageCode,
              child: LanBoardScreen(
                room: room,
                languageCode: widget.languageCode,
              ),
            ),
          ),
        );
      });
    }
    setState(() {});
  }

  Future<Uint8List?> _lanPhoto() async {
    if (!_sharePhoto) return null;
    return LanAvatarCompressor.compress(widget.avatarBytes);
  }

  Future<void> _create() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final photo = await _lanPhoto();
      final room = _bluetoothMode
          ? await LanRoomController.hostBluetooth(
              name: _name.text,
              maxPlayers: _maxPlayers,
              avatarIndex: _avatarIndex,
              avatarBytes: photo,
            )
          : _onlineMode
          ? await LanRoomController.hostViaRelay(
              name: _name.text,
              endpoint: RelayProtocol.endpoint(
                _relayUrl.text,
                requireSecure: kIsWeb && Uri.base.scheme == 'https',
              ),
              maxPlayers: _maxPlayers,
              avatarIndex: _avatarIndex,
              avatarBytes: photo,
            )
          : await LanRoomController.host(
              name: _name.text,
              maxPlayers: _maxPlayers,
              avatarIndex: _avatarIndex,
              avatarBytes: photo,
            );
      if (!mounted) {
        await room.shutdown();
        return;
      }
      _room = room..addListener(_onRoomChange);
      setState(() {});
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final photo = await _lanPhoto();
      late final LanRoomController room;
      if (_bluetoothMode) {
        room = await LanRoomController.joinBluetooth(
          name: _name.text,
          deviceAddress: _bluetoothAddress.text.trim(),
          pin: _pin.text.trim(),
          avatarIndex: _avatarIndex,
          avatarBytes: photo,
        );
      } else if (_onlineMode) {
        room = await LanRoomController.joinRelay(
          name: _name.text,
          endpoint: RelayProtocol.endpoint(
            _relayUrl.text,
            requireSecure: kIsWeb && Uri.base.scheme == 'https',
          ),
          roomCode: _pin.text,
          avatarIndex: _avatarIndex,
          avatarBytes: photo,
        );
      } else {
        final ipText = _ip.text.trim();
        final host = ipText.contains(':') ? ipText.split(':').first : ipText;
        final portText = ipText.contains(':') ? ipText.split(':').last : '';
        final port = portText.isEmpty
            ? LanRoomController.defaultPort
            : int.parse(portText);
        if (port < 1 || port > 65535) {
          throw const FormatException('Invalid port');
        }
        room = await LanRoomController.join(
          name: _name.text,
          hostIp: host,
          pin: _pin.text,
          port: port,
          avatarIndex: _avatarIndex,
          avatarBytes: photo,
        );
      }
      if (!mounted) {
        await room.shutdown();
        return;
      }
      _room = room..addListener(_onRoomChange);
      unawaited(_discovery.stopBrowsing());
      setState(() {});
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String error) {
    if (!mounted) return;
    AppNotices.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: const Color(0xFF9C423C)),
    );
  }

  Future<void> _leave() async {
    final room = _room;
    if (room == null) return;
    room.removeListener(_onRoomChange);
    _room = null;
    await room.shutdown();
    if (mounted) setState(() {});
  }

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF172B2C),
      border: Border.all(color: const Color(0xFF39584F)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Widget _label(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      title,
      style: TextStyle(
        fontFamily: t.font,
        color: kBoardGold,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBoardDark,
    appBar: AppBar(
      backgroundColor: kBoardDark,
      foregroundColor: kBoardGold,
      title: Text(
        t.choose('Multiplayer', 'মাল্টিপ্লেয়ার'),
        style: TextStyle(fontFamily: t.font),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Icon(
                _bluetoothMode
                    ? Icons.bluetooth_rounded
                    : Icons.wifi_tethering_rounded,
                color: kBoardGold,
                size: 65,
              ),
              const SizedBox(height: 10),
              Text(
                'bHiVE Monopoly',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Exo2',
                  fontSize: 29,
                  color: kBoardGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _bluetoothMode
                    ? t.choose(
                        'Play Android-to-Android over Bluetooth, with no internet.',
                        'ইন্টারনেট ছাড়াই অ্যান্ড্রয়েড ফোনে ব্লুটুথের মাধ্যমে খেলুন।',
                      )
                    : _onlineMode
                    ? t.choose(
                        'Create or join a room from Web and Android.',
                        'ওয়েব ও অ্যান্ড্রয়েড থেকে রুম তৈরি বা যোগ দিন।',
                      )
                    : t.choose(
                        'Play together on the same Wi-Fi or hotspot.',
                        'একই ওয়াই-ফাই বা হটস্পটে একসঙ্গে খেলুন।',
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontFamily: t.font),
              ),
              const SizedBox(height: 24),
              if (_room == null) _createJoinPanel() else _waitingPanel(_room!),
              const SizedBox(height: 18),
              Text(
                _bluetoothMode
                    ? t.choose(
                        'Pair Android phones in Bluetooth settings first. '
                            'Then select the host phone and enter the 6-digit PIN. '
                            'Bluetooth needs no internet or relay server.',
                        'আগে অ্যান্ড্রয়েড সেটিংসে ফোনগুলো পেয়ার করুন। '
                            'তারপর হোস্ট ফোন বেছে ৬ সংখ্যার পিন দিন। '
                            'ব্লুটুথে ইন্টারনেট বা রিলে সার্ভার লাগে না।',
                      )
                    : _onlineMode
                    ? t.choose(
                        'Requires a running bHiVE relay service. The room '
                            'creator must keep the browser or app open. '
                            'For HTTPS websites, enter a wss:// relay URL.',
                        'bHiVE রিলে সার্ভার চালু থাকতে হবে। রুম নির্মাতার অ্যাপ '
                            'বা ব্রাউজার চালু রাখতে হবে। HTTPS-এ wss:// ব্যবহার করুন।',
                      )
                    : t.choose(
                        'Local Wi-Fi hosting works on Android/desktop; '
                            'Web may join by IP. Room codes require Online / Server mode.',
                        'স্থানীয় Wi-Fi হোস্ট অ্যান্ড্রয়েড/ডেস্কটপে চলে। '
                            'ওয়েব IP দিয়ে যোগ দিতে পারে। কোডের জন্য অনলাইন মোড বেছে নিন।',
                      ),
                style: TextStyle(
                  fontFamily: t.font,
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _createJoinPanel() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey<String>('relay-online-mode'),
              label: Text(t.choose('Online / Server', 'অনলাইন / সার্ভার')),
              avatar: const Icon(Icons.cloud_outlined, size: 17),
              selected: _onlineMode,
              onSelected: (_) => _changeNetworkMode(true),
            ),
            ChoiceChip(
              key: const ValueKey<String>('relay-lan-mode'),
              label: Text(t.choose('Local Wi-Fi', 'স্থানীয় Wi-Fi')),
              avatar: const Icon(Icons.wifi, size: 17),
              selected: !_onlineMode && !_bluetoothMode,
              onSelected: (_) => _changeNetworkMode(false),
            ),
            if (BluetoothGameBridge.isSupported)
              ChoiceChip(
                key: const ValueKey<String>('bluetooth-offline-mode'),
                label: Text(
                  t.choose('Bluetooth (Offline)', 'ব্লুটুথ (অফলাইন)'),
                ),
                avatar: const Icon(Icons.bluetooth, size: 17),
                selected: _bluetoothMode,
                onSelected: (_) => _changeBluetoothMode(),
              ),
          ],
        ),
        const SizedBox(height: 15),
        if (_onlineMode) ...[
          _label(
            t.choose(
              'Relay server WebSocket URL',
              'রিলে সার্ভারের WebSocket URL',
            ),
          ),
          TextField(
            key: const ValueKey<String>('relay-endpoint-field'),
            controller: _relayUrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'wss://example.com/bhive-relay/ws',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (_onlineMode || !kIsWeb)
              ChoiceChip(
                label: Text(t.choose('Host game', 'হোস্ট করুন')),
                avatar: const Icon(Icons.router_outlined, size: 17),
                selected: _hostMode,
                onSelected: (_) => _changeMode(true),
              ),
            ChoiceChip(
              label: Text(t.choose('Join game', 'যোগ দিন')),
              avatar: const Icon(Icons.login_rounded, size: 17),
              selected: !_hostMode,
              onSelected: (_) => _changeMode(false),
            ),
          ],
        ),
        const SizedBox(height: 19),
        _label(t.choose('Player name', 'খেলোয়াড়ের নাম')),
        TextField(
          controller: _name,
          maxLength: 24,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
            counterText: '',
          ),
        ),
        const SizedBox(height: 9),
        _label(t.choose('Player avatar', 'খেলোয়াড়ের অবতার')),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (var n = 0; n < LanAvatarBadge.icons.length; n++)
              InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => setState(() => _avatarIndex = n),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _avatarIndex == n ? kBoardGold : Colors.white24,
                      width: _avatarIndex == n ? 2.5 : 1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: LanAvatarBadge(
                    member: LanMember(
                      id: n,
                      name: '',
                      avatarIndex: n,
                      avatarBytes: n == _avatarIndex && _sharePhoto
                          ? widget.avatarBytes
                          : null,
                    ),
                    color: PlayerColorPreferences.instance.colorFor(n),
                    radius: 20,
                  ),
                ),
              ),
          ],
        ),
        if (widget.avatarBytes != null) ...[
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _sharePhoto,
            onChanged: (value) => setState(() => _sharePhoto = value),
            title: Text(
              t.choose(
                'Share my profile photo with other players',
                'অন্য খেলোয়াড়দের সাথে আমার ছবি শেয়ার করুন',
              ),
              style: TextStyle(
                fontFamily: t.font,
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              t.choose(
                'Optional: photos are resized to fit 64 KB and sent to room members. '
                    'For remote play, use a secure wss:// relay.',
                'ঐচ্ছিক: ছবি ৬৪ কেবির মধ্যে ছোট করা হয় ও অন্যদের পাঠানো হয়। '
                    'দূরবর্তী খেলায় নিরাপদ wss:// ব্যবহার করুন।',
              ),
              style: TextStyle(
                fontFamily: t.font,
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_hostMode) ...[
          _label(
            t.choose('Room capacity (including host)', 'মোট খেলোয়াড় (হোস্টসহ)'),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (var count = 2; count <= 6; count++)
                ChoiceChip(
                  label: Text(t.integer(count)),
                  selected: _maxPlayers == count,
                  onSelected: (_) => setState(() => _maxPlayers = count),
                ),
            ],
          ),
        ] else ...[
          if (!_onlineMode && !_bluetoothMode && !kIsWeb) ...[
            Row(
              children: [
                Expanded(
                  child: _label(
                    t.choose('Nearby Wi-Fi rooms', 'কাছাকাছি ওয়াই-ফাই রুম'),
                  ),
                ),
                IconButton(
                  tooltip: t.choose('Scan again', 'আবার খুঁজুন'),
                  onPressed: () => unawaited(
                    _discovery.startBrowsing(
                      protocol: LanRoomController.protocolVersion,
                    ),
                  ),
                  icon: const Icon(Icons.refresh, color: kBoardGold),
                ),
              ],
            ),
            if (_discovery.rooms.isEmpty)
              Text(
                t.choose(
                  'Scanning… Use manual IP if no rooms appear.',
                  'খোঁজা হচ্ছে… রুম না পেলে IP দিয়ে যোগ দিন।',
                ),
                style: TextStyle(color: Colors.white70, fontFamily: t.font),
              ),
            for (final found in _discovery.rooms)
              Card(
                color: const Color(0xFF24413B),
                child: ListTile(
                  leading: const Icon(Icons.wifi, color: kBoardGold),
                  title: Text(
                    found.hostName,
                    style: TextStyle(fontFamily: t.font, color: Colors.white),
                  ),
                  subtitle: Text(
                    '${found.hostIp}:${found.port} • '
                    '${t.integer(found.playerCount)}/${t.integer(found.capacity)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: OutlinedButton(
                    onPressed: found.isFull
                        ? null
                        : () => setState(() {
                            _ip.text = '${found.hostIp}:${found.port}';
                          }),
                    child: Text(t.choose('Select', 'নির্বাচন')),
                  ),
                  onTap: found.isFull
                      ? null
                      : () => setState(() {
                          _ip.text = '${found.hostIp}:${found.port}';
                        }),
                ),
              ),
            if (_discovery.lastError != null)
              Text(
                _discovery.lastError!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            const SizedBox(height: 14),
          ],
          if (_bluetoothMode) ...[_bluetoothJoinPanel()],
          if (!_onlineMode && !_bluetoothMode) ...[
            _label(
              t.choose(
                'Host IP address (e.g. 192.168.1.5)',
                'হোস্ট IP (যেমন 192.168.1.5)',
              ),
            ),
            TextField(
              controller: _ip,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '192.168.1.5:8787',
                prefixIcon: Icon(Icons.lan_outlined),
              ),
            ),
            const SizedBox(height: 14),
          ],
          _label(
            _onlineMode
                ? t.choose('8-character room code', '৮ অক্ষরের রুম কোড')
                : t.choose('6-digit room PIN', '৬ সংখ্যার রুম পিন'),
          ),
          TextField(
            key: const ValueKey<String>('relay-room-code-field'),
            controller: _pin,
            keyboardType: _onlineMode
                ? TextInputType.text
                : TextInputType.number,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: _onlineMode
                ? <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(8),
                  ]
                : <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
        ],
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _loading ? null : (_hostMode ? _create : _join),
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_hostMode ? Icons.wifi_tethering : Icons.login),
          label: Text(
            _hostMode
                ? t.choose('CREATE ROOM', 'রুম তৈরি করুন')
                : t.choose('JOIN ROOM', 'রুমে যোগ দিন'),
            style: TextStyle(fontFamily: t.font),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: kBoardGold,
            foregroundColor: kBoardDark,
            minimumSize: const Size.fromHeight(54),
          ),
        ),
      ],
    ),
  );

  Widget _bluetoothJoinPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: _label(
              t.choose('Paired Android phones', 'পেয়ার করা অ্যান্ড্রয়েড ফোন'),
            ),
          ),
          IconButton(
            key: const ValueKey<String>('bluetooth-refresh'),
            tooltip: t.choose(
              'Refresh paired phones',
              'পেয়ার ফোনগুলো আবার দেখুন',
            ),
            onPressed: _loadingBluetoothDevices
                ? null
                : _refreshBluetoothDevices,
            icon: const Icon(Icons.refresh_rounded, color: kBoardGold),
          ),
        ],
      ),
      if (_loadingBluetoothDevices) const LinearProgressIndicator(),
      if (_pairedBluetoothDevices.isEmpty && !_loadingBluetoothDevices)
        Text(
          t.choose(
            'No paired phones found. Pair with the host from Android Bluetooth settings, then refresh.',
            'পেয়ার করা ফোন নেই। অ্যান্ড্রয়েড ব্লুটুথ সেটিংসে হোস্টের সাথে পেয়ার করে রিফ্রেশ করুন।',
          ),
          style: TextStyle(color: Colors.white70, fontFamily: t.font),
        ),
      for (final device in _pairedBluetoothDevices)
        ListTile(
          key: ValueKey<String>('bluetooth-device-${device.address}'),
          leading: Icon(
            _bluetoothAddress.text == device.address
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: kBoardGold,
          ),
          title: Text(device.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            device.address,
            style: const TextStyle(color: Colors.white60),
          ),
          onTap: () => setState(() => _bluetoothAddress.text = device.address),
        ),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        onPressed: () => unawaited(BluetoothGameBridge.instance.openSettings()),
        icon: const Icon(Icons.settings_bluetooth),
        label: Text(
          t.choose(
            'Open Android Bluetooth pairing',
            'অ্যান্ড্রয়েড ব্লুটুথ পেয়ারিং খুলুন',
          ),
        ),
      ),
      const SizedBox(height: 12),
    ],
  );

  Widget _waitingPanel(LanRoomController room) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          room.isHost
              ? t.choose(
                  'Room created — waiting for players',
                  'রুম তৈরি হয়েছে — খেলোয়াড়দের অপেক্ষায়',
                )
              : t.choose(
                  'Connected — waiting for host',
                  'সংযুক্ত — হোস্টের অপেক্ষায়',
                ),
          style: TextStyle(
            fontFamily: t.font,
            color: kBoardGold,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),
        if (room.isHost) ...[
          if (room.isRelayRoom) ...[
            _label(t.choose('Relay server', 'রিলে সার্ভার')),
            SelectableText(
              room.relayUri!.toString(),
              style: const TextStyle(color: Colors.white70),
            ),
          ] else if (room.isBluetoothRoom) ...[
            _label(t.choose('Bluetooth host', 'ব্লুটুথ হোস্ট')),
            Text(
              t.choose(
                'Bluetooth room ready. Ask friends to pair with this Android phone '
                    'in Bluetooth settings, then join using the PIN below.',
                'ব্লুটুথ রুম প্রস্তুত। বন্ধুদের ফোনটি ব্লুটুথ সেটিংসে পেয়ার '
                    'করে নিচের পিন দিয়ে যোগ দিতে বলুন।',
              ),
              style: TextStyle(color: Colors.white70, fontFamily: t.font),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () =>
                  unawaited(BluetoothGameBridge.instance.openSettings()),
              icon: const Icon(Icons.settings_bluetooth_rounded),
              label: Text(t.choose('Bluetooth settings', 'ব্লুটুথ সেটিংস')),
            ),
          ] else ...[
            _label(t.choose('Host device IP', 'হোস্ট ডিভাইসের IP')),
            for (final address in room.hostAddresses)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: SelectableText(
                  '$address:${room.port}',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, color: kBoardGold),
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: '$address:${room.port}'),
                  ),
                ),
              ),
            if (room.hostAddresses.isEmpty)
              Text(
                t.choose(
                  'Find your Wi-Fi IPv4 address in device settings.',
                  'ডিভাইসের সেটিংস থেকে Wi-Fi IPv4 ঠিকানা দেখুন।',
                ),
                style: const TextStyle(color: Colors.white70),
              ),
            Text(
              t.choose(
                'The room is advertised on local Wi-Fi when broadcast '
                    'is permitted. Share the PIN separately.',
                'নেটওয়ার্ক অনুমতি দিলে রুমটি ওয়াই-ফাইতে দেখা যাবে। PIN আলাদা করে দিন।',
              ),
              style: TextStyle(
                fontFamily: t.font,
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _label(
            room.isRelayRoom
                ? t.choose('Share this room code', 'এই রুম কোডটি শেয়ার করুন')
                : t.choose(
                    'Give players this room PIN',
                    'খেলোয়াড়দের এই রুম পিন দিন',
                  ),
          ),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  room.pin,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Exo2',
                    fontSize: 33,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey<String>('relay-copy-code'),
                icon: const Icon(Icons.copy, color: kBoardGold),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: room.pin)),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        _label(
          t.choose(
            'Players (${room.connectedPlayers})',
            'খেলোয়াড় (${t.integer(room.connectedPlayers)})',
          ),
        ),
        for (final member in room.members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: LanAvatarBadge(
              member: member,
              color: PlayerColorPreferences.instance.colorFor(member.id),
              radius: 20,
            ),
            title: Text(
              member.name,
              style: TextStyle(fontFamily: t.font, color: Colors.white),
            ),
            trailing: Icon(
              member.connected ? Icons.check_circle : Icons.wifi_off,
              color: member.connected
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
            ),
          ),
        if (room.members.isEmpty)
          const LinearProgressIndicator(color: kBoardGold),
        const SizedBox(height: 17),
        if (room.isHost) ...[
          FilledButton.icon(
            onPressed: room.canStart ? room.startMatch : null,
            style: FilledButton.styleFrom(
              backgroundColor: kBoardGold,
              foregroundColor: kBoardDark,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              t.choose(
                'START MATCH (2+ players)',
                'খেলা শুরু করুন (২+ খেলোয়াড়)',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _leave,
          icon: const Icon(Icons.logout),
          label: Text(t.choose('LEAVE ROOM', 'রুম ছাড়ুন')),
        ),
      ],
    ),
  );
}
