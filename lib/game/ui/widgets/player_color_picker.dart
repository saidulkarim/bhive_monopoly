import 'package:flutter/material.dart';

import '../../experience/player_palette.dart';

/// Selection dialog disables all colors already used by another player.
/// The caller chooses which seat is being edited.
Future<void> showPlayerColorPicker(
  BuildContext context, {
  required int seat,
  required String languageCode,
  int activeSeats = 6,
}) async {
  final colors = PlayerColorPreferences.instance;
  await colors.ensureLoaded();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF162B2C),
      title: Text(
        languageCode == 'bn' ? 'খেলোয়াড়ের রং' : 'Choose player color',
      ),
      content: SizedBox(
        width: 360,
        child: AnimatedBuilder(
          animation: colors,
          builder: (ctx, _) => Wrap(
            spacing: 11,
            runSpacing: 12,
            children: [
              for (var i = 0; i < PlayerPalette.colors.length; i++)
                Tooltip(
                  message:
                      '${PlayerPalette.labels[i]}${colors.isTaken(i, exceptSeat: seat, activeSeats: activeSeats) ? ' · Unavailable' : ''}',
                  child: InkWell(
                    key: ValueKey('player-color-$i'),
                    borderRadius: BorderRadius.circular(18),
                    onTap:
                        colors.isTaken(
                          i,
                          exceptSeat: seat,
                          activeSeats: activeSeats,
                        )
                        ? null
                        : () async {
                            final selected = await colors.select(
                              seat,
                              i,
                              activeSeats: activeSeats,
                            );
                            if (selected && dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                    child: Opacity(
                      opacity:
                          colors.isTaken(
                            i,
                            exceptSeat: seat,
                            activeSeats: activeSeats,
                          )
                          ? .28
                          : 1,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: PlayerPalette.at(i),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: colors.indexFor(seat) == i
                                ? Colors.white
                                : Colors.white24,
                            width: colors.indexFor(seat) == i ? 3 : 1,
                          ),
                        ),
                        child: Icon(
                          colors.indexFor(seat) == i
                              ? Icons.check_rounded
                              : colors.isTaken(
                                  i,
                                  exceptSeat: seat,
                                  activeSeats: activeSeats,
                                )
                              ? Icons.lock_outline_rounded
                              : Icons.circle_outlined,
                          color: const Color(0xFF102C2E),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(languageCode == 'bn' ? 'বন্ধ করুন' : 'Close'),
        ),
      ],
    ),
  );
}
