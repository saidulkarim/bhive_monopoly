import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/ui/app_notices.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/avatar_encoder.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/app_controller.dart';
import '../widgets/player_avatar.dart';
import '../../core/utils/avatar_preview_bytes.dart';
import '../../game/experience/player_palette.dart';
import '../../game/ui/widgets/player_color_picker.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _name;
  late int _preset;
  String? _photo;
  final _avatarPreview = AvatarPreviewBytes();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(appControllerProvider).requireValue;
    _name = TextEditingController(text: profile.displayName);
    _preset = profile.avatarIndex;
    _photo = profile.avatarBase64;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _recoverPickedImage();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _recoverPickedImage() async {
    setState(() => _busy = true);
    try {
      final result = await _picker.retrieveLostData();
      if (result.exception != null) throw result.exception!;
      final files = result.files;
      if (files != null && files.isNotEmpty) {
        await _loadPhoto(files.first);
      }
    } catch (_) {
      if (mounted) _showError(AppLocalizations.of(context).photoError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadPhoto(XFile file) async {
    if (await file.length() > 10 * 1024 * 1024) {
      throw const FormatException('Image exceeds 10 MiB');
    }
    final encoded = await compute(encodeAvatar, await file.readAsBytes());
    if (mounted) setState(() => _photo = encoded);
  }

  Future<void> _choosePhoto(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null) await _loadPhoto(file);
    } catch (_) {
      if (mounted) _showError(AppLocalizations.of(context).photoError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    AppNotices.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref
          .read(appControllerProvider.notifier)
          .saveProfile(_name.text, _preset, _photo);
      if (!mounted) return;
      setState(() => _busy = false);
      AppNotices.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileSaved)),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _showError(AppLocalizations.of(context).saveError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bytes = _avatarPreview.resolve(_photo);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.editProfile)),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: PlayerAvatar(
                          preset: _preset,
                          bytes: bytes,
                          size: 112,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _name,
                        enabled: !_busy,
                        maxLength: 40,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.displayName,
                          prefixIcon: IconButton(
                            key: const ValueKey<String>('profile-player-color'),
                            tooltip:
                                Localizations.localeOf(context).languageCode ==
                                    'bn'
                                ? 'আপনার রং নির্বাচন করুন'
                                : 'Choose your player color',
                            onPressed: _busy
                                ? null
                                : () async {
                                    await showPlayerColorPicker(
                                      context,
                                      seat: 0,
                                      languageCode: Localizations.localeOf(
                                        context,
                                      ).languageCode,
                                      activeSeats: 1,
                                    );
                                    if (mounted) setState(() {});
                                  },
                            icon: Container(
                              width: 25,
                              height: 25,
                              decoration: BoxDecoration(
                                color: PlayerColorPreferences.instance.colorFor(
                                  0,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        validator: (value) {
                          final length = (value ?? '').trim().runes.length;
                          return length < 2 || length > 40
                              ? l10n.nameValidation
                              : null;
                        },
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.chooseAvatar,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: List.generate(playerAvatarIcons.length, (i) {
                          return Semantics(
                            label: l10n.avatarName(i + 1),
                            selected: _photo == null && _preset == i,
                            child: ChoiceChip(
                              label: Icon(playerAvatarIcons[i], size: 28),
                              selected: _photo == null && _preset == i,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(() {
                                      _preset = i;
                                      _photo = null;
                                    }),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _choosePhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(l10n.choosePhoto),
                          ),
                          if (!kIsWeb &&
                              defaultTargetPlatform == TargetPlatform.android)
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _choosePhoto(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: Text(l10n.takePhoto),
                            ),
                          if (_photo != null)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _photo = null),
                              child: Text(l10n.removePhoto),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.photoHint),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(l10n.saveProfile),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
