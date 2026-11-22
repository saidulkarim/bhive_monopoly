/// Presentation-only camera configuration. Does not alter game rules,
/// deterministic turns, network packets, or game saves.
enum BoardCameraPreset {
  topDown,
  tabletop,
  cinematic;

  static BoardCameraPreset fromStored(String? value) {
    for (final preset in BoardCameraPreset.values) {
      if (preset.name == value) return preset;
    }
    return BoardCameraPreset.tabletop;
  }

  String label(bool bangla) => switch (this) {
    BoardCameraPreset.topDown => bangla ? 'উপর থেকে' : 'Top-down',
    BoardCameraPreset.tabletop => bangla ? 'টেবিল ভিউ' : 'Tabletop',
    BoardCameraPreset.cinematic => bangla ? 'সিনেমাটিক' : 'Cinematic',
  };

  double get tilt => switch (this) {
    BoardCameraPreset.topDown => 0.0,
    BoardCameraPreset.tabletop => -0.22,
    BoardCameraPreset.cinematic => -0.35,
  };

  double get spin => this == BoardCameraPreset.cinematic ? -.055 : 0.0;

  double get depth => switch (this) {
    BoardCameraPreset.topDown => 0.0,
    BoardCameraPreset.tabletop => .0005,
    BoardCameraPreset.cinematic => .0008,
  };
}
