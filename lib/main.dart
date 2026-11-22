// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'providers/app_controller.dart';
import 'ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
                    const Text(
                      'Could not load your profile.\nপ্রোফাইল লোড করা যায়নি।',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => ref.invalidate(appControllerProvider),
                      child: const Text('Retry / আবার চেষ্টা করুন'),
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
