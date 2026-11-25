import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../game/ui/game_text.dart';
import '../../game/ui/game_typography.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key, required this.languageCode});
  final String languageCode;
  static const mobile = '+8801312663311';
  static const email = 'saidul.cse.ju@gmail.com';

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  late final Future<PackageInfo> _package = PackageInfo.fromPlatform();
  GameText get t => GameText(widget.languageCode);

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      _notice(t.choose('Copied to clipboard.', 'কপি করা হয়েছে।'));
    } catch (_) {
      _notice(t.choose('Unable to copy.', 'কপি করা যায়নি।'));
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // Desktop/web may not have a registered telephone or mail handler.
    }
    _notice(
      t.choose(
        'No compatible app found. You can copy the contact instead.',
        'উপযুক্ত অ্যাপ পাওয়া যায়নি। যোগাযোগের তথ্য কপি করতে পারেন।',
      ),
    );
  }

  Widget _contact(IconData icon, String title, String value, String scheme) =>
      Card(
        color: AppTheme.panel,
        child: ListTile(
          leading: Icon(icon, color: AppTheme.gold),
          title: Text(title),
          subtitle: SelectableText(
            value,
            style: const TextStyle(fontFamily: 'Exo2', color: Colors.white),
          ),
          onTap: () => _open(Uri(scheme: scheme, path: value)),
          trailing: IconButton(
            tooltip: t.choose('Copy', 'কপি করুন'),
            onPressed: () => _copy(value),
            icon: const Icon(Icons.copy_rounded, color: AppTheme.gold),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => GameTypography(
    languageCode: widget.languageCode,
    child: Scaffold(
      backgroundColor: AppTheme.obsidian,
      appBar: AppBar(title: Text(t.choose('Credits', 'কৃতজ্ঞতা ও পরিচিতি'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.domain_rounded,
                        size: 96,
                        color: AppTheme.gold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'bHiVE Monopoly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Exo2',
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.choose(
                    'A strategic property trading game',
                    'কৌশলভিত্তিক সম্পত্তি বাণিজ্যের খেলা',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  t.choose('Design & Development', 'ডিজাইন ও ডেভেলপমেন্ট'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.gold, fontSize: 18),
                ),
                const Text(
                  'bHiVE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Exo2',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  t.choose('Contact information', 'যোগাযোগের তথ্য'),
                  style: const TextStyle(color: AppTheme.gold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                _contact(
                  Icons.phone_rounded,
                  t.choose('Mobile', 'মোবাইল'),
                  CreditsScreen.mobile,
                  'tel',
                ),
                _contact(
                  Icons.email_rounded,
                  t.choose('Email', 'ই-মেইল'),
                  CreditsScreen.email,
                  'mailto',
                ),
                const SizedBox(height: 16),
                FutureBuilder<PackageInfo>(
                  future: _package,
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    return Text(
                      info == null
                          ? t.choose(
                              'Application version unavailable',
                              'অ্যাপের সংস্করণ পাওয়া যায়নি',
                            )
                          : '${t.choose('Version', 'সংস্করণ')} ${t.digits(info.version)} (${t.digits(info.buildNumber)})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  t.choose(
                    'Special thanks to everyone who plays and helps improve the game.',
                    'খেলাটি খেলছেন এবং উন্নয়নে সহযোগিতা করছেন—সকলকে বিশেষ ধন্যবাদ।',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  t.choose(
                    'Independent game project. It has no connection with the owners of the MONOPOLY trademark.',
                    'এটি একটি স্বাধীন গেম প্রকল্প। MONOPOLY ট্রেডমার্কের মালিকদের সঙ্গে এর কোনো সম্পর্ক নেই।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse('https://imrony.dev');

                    if (!await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                      webOnlyWindowName: '_blank',
                    )) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            t.choose(
                              'Unable to open website.',
                              'ওয়েবসাইটটি খোলা যাচ্ছে না।',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.language_rounded),
                  label: Text(t.choose('imrony.dev', 'imrony.dev')),
                ),
                Text(
                  '© ${t.integer(DateTime.now().year)} bHiVE · ${t.choose('All rights reserved', 'সর্বস্বত্ব সংরক্ষিত')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.gold, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
