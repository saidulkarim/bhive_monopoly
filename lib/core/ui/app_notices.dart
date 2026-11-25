import 'dart:async';

import 'package:flutter/material.dart';

/// Presents transient messages *above the Navigator*, including modal sheets,
/// dialogs, the full-screen explorer and animated boards.
///
/// Replace ScaffoldMessenger.of(context) with AppNotices.of(context) for
/// existing SnackBar call sites; existing messages, duration and error colors
/// remain intact. The app's MaterialApp.builder must wrap its navigator with
/// [AppNoticeOverlay].
class AppNotices {
  AppNotices._();

  static final ValueNotifier<SnackBar?> _current = ValueNotifier<SnackBar?>(
    null,
  );
  static Timer? _dismissTimer;

  static AppNoticeMessenger of(BuildContext context) =>
      const AppNoticeMessenger._();

  static void _show(SnackBar snackBar) {
    _dismissTimer?.cancel();
    _current.value = snackBar;
    _dismissTimer = Timer(
      snackBar.duration < const Duration(seconds: 5)
          ? const Duration(seconds: 5)
          : snackBar.duration,
      hideCurrentSnackBar,
    );
  }

  static void hideCurrentSnackBar() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _current.value = null;
  }
}

/// Small compatibility adapter so existing SnackBar-based call sites do not
/// need their messages or bilingual formatting rewritten.
class AppNoticeMessenger {
  const AppNoticeMessenger._();

  void showSnackBar(SnackBar snackBar) => AppNotices._show(snackBar);

  void hideCurrentSnackBar() => AppNotices.hideCurrentSnackBar();
}

/// This widget sits above the entire Navigator, not inside a Scaffold.
/// That ordering is what guarantees readable messages over bottom sheets.
class AppNoticeOverlay extends StatefulWidget {
  const AppNoticeOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<AppNoticeOverlay> createState() => _AppNoticeOverlayState();
}

class _AppNoticeOverlayState extends State<AppNoticeOverlay> {
  @override
  void dispose() {
    // A pending notice timeout belongs to this app root. Cancel it when
    // the root is removed (including widget tests and app teardown), rather
    // than leaving a Timer alive after its UI is gone.
    AppNotices.hideCurrentSnackBar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      widget.child,
      ValueListenableBuilder<SnackBar?>(
        valueListenable: AppNotices._current,
        builder: (context, message, _) {
          if (message == null) return const SizedBox.shrink();
          final error = message.backgroundColor != null;
          final background = message.backgroundColor ?? const Color(0xFF183635);
          return Positioned(
            top: MediaQuery.viewPaddingOf(context).top + 10,
            left: 12,
            right: 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Semantics(
                  liveRegion: true,
                  child: Material(
                    key: const ValueKey<String>('app-top-notice'),
                    elevation: 18,
                    color: background,
                    shadowColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: error
                            ? const Color(0xFFFFB4AC)
                            : const Color(0xFFE3C477),
                        width: 1.3,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
                      child: Row(
                        // Use the finite notice width so its text can wrap
                        // instead of expanding beyond narrow viewports.
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          Icon(
                            error
                                ? Icons.error_outline_rounded
                                : Icons.info_outline_rounded,
                            color: error
                                ? const Color(0xFFFFD7D4)
                                : const Color(0xFFE3C477),
                            size: 23,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.3,
                              ),
                              child: message.content,
                            ),
                          ),
                          // The notice is drawn above MaterialApp's
                          // Navigator. IconButton.tooltip creates a
                          // RawTooltip that needs an Overlay ancestor,
                          // which this root-level layer does not have.
                          // Keep an accessible label without Tooltip.
                          Semantics(
                            label:
                                Localizations.localeOf(context).languageCode ==
                                    'bn'
                                ? 'বার্তা বন্ধ করুন'
                                : 'Dismiss notification',
                            button: true,
                            child: IconButton(
                              key: const ValueKey<String>(
                                'app-top-notice-dismiss',
                              ),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                              onPressed: AppNotices.hideCurrentSnackBar,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}
