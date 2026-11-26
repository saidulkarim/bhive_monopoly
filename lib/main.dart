// ignore_for_file: unnecessary_underscores

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/ui/app_notices.dart';
import 'core/ui/visual_activity_scope.dart';
import 'core/ui/game_diagnostics.dart';
import 'core/utils/currency_preferences.dart';
import 'game/experience/player_palette.dart';
import 'core/fonts/font_app_builder.dart';
import 'l10n/generated/app_localizations.dart';
import 'providers/app_controller.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final previousFrameworkHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    GameDiagnostics.record(
      'Flutter framework',
      details.exception,
      details.stack ?? StackTrace.empty,
    );
    previousFrameworkHandler?.call(details);
  };
  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'bHiVE Monopoly',
        context: ErrorDescription(
          'while handling an uncaught asynchronous error',
        ),
      ),
    );
    // Do not claim recovery or suppress an unknown integrity failure.
    return previousPlatformHandler?.call(error, stack) ?? false;
  };
  await Future.wait(<Future<void>>[
    CurrencyPreferences.instance.ensureLoaded(),
    PlayerColorPreferences.instance.ensureLoaded(),
  ]);
  runApp(const ProviderScope(child: MonopolyApp()));
}

class MonopolyApp extends ConsumerWidget {
  const MonopolyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appControllerProvider);
    final language = settings.asData?.value.languageCode ?? 'en';
    return MaterialApp(
      title: 'bHiVE Monopoly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(languageCode: language),
      // Keep the saved choice effective on every route and dialog.
      builder: (context, child) => FontAppBuilder(
        languageCode: language,
        child: VisualActivityScope(
          child: AppNoticeOverlay(child: child ?? const SizedBox.shrink()),
        ),
      ),
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: settings.when(
        data: (_) => const HomeScreen(),
        loading: () => const Scaffold(
          body: SafeArea(child: Center(child: CircularProgressIndicator())),
        ),
        error: (_, __) => Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      language == 'bn'
                          ? 'প্রোফাইল লোড করা যায়নি।'
                          : 'Could not load your profile.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => ref.invalidate(appControllerProvider),
                      child: Text(
                        language == 'bn' ? 'আবার চেষ্টা করুন' : 'Retry',
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
  }
}
