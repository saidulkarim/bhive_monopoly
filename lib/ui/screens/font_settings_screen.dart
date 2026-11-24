import 'package:flutter/material.dart';

import '../../core/ui/app_notices.dart';

import '../../core/fonts/font_catalog.dart';
import '../../core/utils/currency_preferences.dart';
import '../../core/fonts/font_preferences.dart';
import '../../core/theme/app_theme.dart';

/// One page for selecting two persistent UI fonts independently.
/// Previews change immediately; Save makes the selection the default.
class FontSettingsScreen extends StatefulWidget {
  const FontSettingsScreen({super.key, required this.languageCode});

  final String languageCode;

  @override
  State<FontSettingsScreen> createState() => _FontSettingsScreenState();
}

class _FontSettingsScreenState extends State<FontSettingsScreen> {
  final TextEditingController _bnPreview = TextEditingController(
    text: 'স্বাগতম! খেলা শুরু করুন • সম্পত্তি কিনুন • ৳১,৫০০',
  );
  final TextEditingController _enPreview = TextEditingController(
    text: 'Welcome! Start game • Buy property • \$1,500',
  );

  String _bangla = FontCatalog.defaultBangla;
  String _english = FontCatalog.defaultEnglish;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _bn => widget.languageCode == 'bn';
  bool get _hasChanges =>
      _bangla != FontPreferences.instance.banglaFamily ||
      _english != FontPreferences.instance.englishFamily;

  String _text(String english, String bangla) => _bn ? bangla : english;

  @override
  void initState() {
    super.initState();
    final currencyEn = CurrencyPreferences.instance.codeFor('en') == 'BDT'
        ? '৳'
        : r'$';
    final currencyBn = CurrencyPreferences.instance.codeFor('bn') == 'BDT'
        ? '৳'
        : r'$';
    _enPreview.text = 'Welcome! Start game • Buy property • ${currencyEn}1,500';
    _bnPreview.text =
        'স্বাগতম! খেলা শুরু করুন • সম্পত্তি কিনুন • $currencyBn১,৫০০';
    _loadSelections();
  }

  Future<void> _loadSelections() async {
    try {
      await FontPreferences.instance.load();
      if (!mounted) return;
      setState(() {
        _bangla = FontPreferences.instance.banglaFamily;
        _english = FontPreferences.instance.englishFamily;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _loading || !_hasChanges) return;
    setState(() => _saving = true);
    try {
      await FontPreferences.instance.save(
        banglaFamily: _bangla,
        englishFamily: _english,
      );
      if (!mounted) return;
      AppNotices.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF196F4C),
          content: Text(
            _text(
              'Font defaults saved for both languages.',
              'দুই ভাষার ডিফল্ট ফন্ট সংরক্ষণ করা হয়েছে।',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AppNotices.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            _text(
              'Could not save fonts. $error',
              'ফন্ট সংরক্ষণ করা যায়নি। $error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetSelection() {
    setState(() {
      _bangla = FontCatalog.defaultBangla;
      _english = FontCatalog.defaultEnglish;
    });
    AppNotices.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _text(
            'Default fonts selected. Tap Save to apply them.',
            'ডিফল্ট ফন্ট নির্বাচন হয়েছে। প্রয়োগ করতে সংরক্ষণ চাপুন।',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bnPreview.dispose();
    _enPreview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.obsidian,
    appBar: AppBar(
      title: Text(_text('Font Settings', 'ফন্ট সেটিংস')),
      backgroundColor: AppTheme.obsidian,
      foregroundColor: AppTheme.gold,
      actions: [
        IconButton(
          tooltip: _text('Restore defaults', 'ডিফল্ট ফন্ট'),
          icon: const Icon(Icons.restart_alt_rounded),
          onPressed: _loading || _saving ? null : _resetSelection,
        ),
      ],
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _text(
                        'Font preferences could not be loaded.',
                        'ফন্টের সেটিংস লোড করা যায়নি।',
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _loadError = null;
                        });
                        _loadSelections();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(_text('Try again', 'আবার চেষ্টা করুন')),
                    ),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 860;
                final banglaPanel = _languagePanel(
                  code: 'bn',
                  title: _text('Bangla / বাংলা', 'বাংলা ফন্ট'),
                  subtitle: _text(
                    'Default: KarnaphuliMJ',
                    'ডিফল্ট: KarnaphuliMJ',
                  ),
                  selected: _bangla,
                  controller: _bnPreview,
                );
                final englishPanel = _languagePanel(
                  code: 'en',
                  title: _text('English', 'ইংরেজি ফন্ট'),
                  subtitle: _text('Default: Exo2', 'ডিফল্ট: Exo2'),
                  selected: _english,
                  controller: _enPreview,
                );
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                      children: [
                        _header(),
                        const SizedBox(height: 20),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: banglaPanel),
                              const SizedBox(width: 16),
                              Expanded(child: englishPanel),
                            ],
                          )
                        else ...[
                          banglaPanel,
                          const SizedBox(height: 16),
                          englishPanel,
                        ],
                        const SizedBox(height: 24),
                        _footer(),
                      ],
                    ),
                  ),
                );
              },
            ),
    ),
  );

  Widget _header() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF123D37), Color(0xFF152124)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF4B684F)),
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 12,
      children: [
        const Icon(Icons.font_download_rounded, size: 46, color: AppTheme.gold),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('Personalize your game', 'গেমের ফন্ট নিজের মতো বেছে নিন'),
              style: const TextStyle(
                fontSize: 22,
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _text(
                'Choose separate default fonts for Bangla and English. '
                    'Preview first, then save your choice.',
                'বাংলা ও ইংরেজির জন্য আলাদা ডিফল্ট ফন্ট নির্বাচন করুন। '
                    'আগে দেখে নিন, তারপর সংরক্ষণ করুন।',
              ),
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _languagePanel({
    required String code,
    required String title,
    required String subtitle,
    required String selected,
    required TextEditingController controller,
  }) {
    final options = FontCatalog.forLanguage(code);
    final renderedFamily = FontCatalog.renderFamily(code, selected);
    final currentFallbacks = FontCatalog.renderFallbacks(code, selected);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF345348)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _fontOption(
                option: option,
                selected: selected == option.family,
                onTap: _saving
                    ? null
                    : () => setState(() {
                        if (code == 'bn') {
                          _bangla = option.family;
                        } else {
                          _english = option.family;
                        }
                      }),
              ),
            ),
          if (code == 'bn' &&
              selected == 'KarnaphuliMJ' &&
              !FontCatalog.karnaphuliSupportsUnicodeUi) ...<Widget>[
            const SizedBox(height: 7),
            Text(
              _text(
                'KarnaphuliMJ remains selected. This font file displays'
                    ' Unicode Bangla incorrectly, so Nikosh is used'
                    ' to keep the interface readable.',
                'KarnaphuliMJ নির্বাচিত আছে। ইউনিকোড বাংলা স্পষ্ট দেখাতে'
                    ' আপাতত Nikosh ব্যবহার করা হচ্ছে।',
              ),
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _text('Live preview', 'সরাসরি প্রিভিউ'),
            style: const TextStyle(
              color: AppTheme.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontFamily: renderedFamily,
              fontFamilyFallback: currentFallbacks,
              color: Colors.white,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: _text('Type text to preview', 'লিখে পরীক্ষা করুন'),
              filled: true,
              fillColor: const Color(0xFF172B2B),
              contentPadding: const EdgeInsets.all(13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF536B65)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.gold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF102326),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF395852)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.text.isEmpty ? 'Aa / অ আ ক খ' : controller.text,
                  style: TextStyle(
                    fontFamily: renderedFamily,
                    fontFamilyFallback: currentFallbacks,
                    color: Colors.white,
                    fontSize: 23,
                    height: code == 'bn' ? 1.42 : 1.23,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _text('Selected: $selected', 'নির্বাচিত: $selected'),
                  style: const TextStyle(color: AppTheme.gold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fontOption({
    required FontChoice option,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final fallback = FontCatalog.renderFallbacks(
      option.languageCode,
      option.family,
    );
    final renderFamily = FontCatalog.renderFamily(
      option.languageCode,
      option.family,
    );
    final sample = option.languageCode == 'bn'
        ? 'বাংলাদেশ · শুভ সকাল · ১২৩৪৫'
        : 'MONOPOLY · abc 12345';
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label} ${option.languageCode}',
      child: Material(
        color: selected ? const Color(0xFF214C3D) : const Color(0xFF1A3030),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppTheme.gold : const Color(0xFF3D5551),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppTheme.gold : Colors.white54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sample,
                        style: TextStyle(
                          fontFamily: renderFamily,
                          fontFamilyFallback: fallback,
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _text(
          'Your choices become the default after saving and remain '
              'selected when you restart the application. '
              'The bHiVE logo continues using Exo2.',
          'সংরক্ষণ করার পর নির্বাচিত ফন্ট ডিফল্ট হবে এবং পরেরবার অ্যাপ '
              'চালু করলেও থাকবে। bHiVE লোগোতে Exo2 থাকবে।',
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _saving || !_hasChanges ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.gold,
          foregroundColor: AppTheme.obsidian,
          minimumSize: const Size.fromHeight(54),
        ),
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          _saving
              ? _text('Saving...', 'সংরক্ষণ হচ্ছে...')
              : _text('SAVE DEFAULT FONTS', 'ডিফল্ট ফন্ট সংরক্ষণ করুন'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _saving ? null : _resetSelection,
        icon: const Icon(Icons.restart_alt_rounded),
        label: Text(
          _text(
            'Restore KarnaphuliMJ / Exo2',
            'KarnaphuliMJ / Exo2 ফিরিয়ে আনুন',
          ),
        ),
      ),
    ],
  );
}
