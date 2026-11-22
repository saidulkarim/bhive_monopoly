import 'dart:convert';
import 'dart:typed_data';

class AppState {
  const AppState({
    this.languageCode = 'en',
    this.displayName = '',
    this.avatarIndex = 0,
    this.avatarBase64,
    this.isSaving = false,
  });

  final String languageCode;
  final String displayName;
  final int avatarIndex;
  final String? avatarBase64;
  final bool isSaving;

  Uint8List? get avatarBytes {
    final encoded = avatarBase64;
    if (encoded == null) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  }

  AppState withLanguage(String code) => AppState(
    languageCode: code,
    displayName: displayName,
    avatarIndex: avatarIndex,
    avatarBase64: avatarBase64,
  );

  AppState withProfile(String name, int preset, String? photo) => AppState(
    languageCode: languageCode,
    displayName: name,
    avatarIndex: preset,
    avatarBase64: photo,
  );

  AppState saving() => AppState(
    languageCode: languageCode,
    displayName: displayName,
    avatarIndex: avatarIndex,
    avatarBase64: avatarBase64,
    isSaving: true,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'languageCode': languageCode,
    'displayName': displayName,
    'avatarIndex': avatarIndex,
    'avatarBase64': avatarBase64,
  };

  factory AppState.fromJson(Map<String, dynamic> json) {
    final language = json['languageCode'];
    final name = json['displayName'];
    final index = json['avatarIndex'];
    final photo = json['avatarBase64'];
    return AppState(
      languageCode: language == 'bn' ? 'bn' : 'en',
      displayName: name is String ? name : '',
      avatarIndex: index is int && index >= 0 && index < 6 ? index : 0,
      avatarBase64: photo is String && photo.length <= 100000 ? photo : null,
    );
  }
}
