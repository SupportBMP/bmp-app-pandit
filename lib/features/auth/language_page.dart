import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';

/// First-launch language picker (LanguageSelection.js). Also reused from the
/// profile screen via [showLanguageSheet].
class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  String? _selected;

  Future<void> _continue() async {
    if (_selected == null) return;
    await I18n.change(_selected!);
    if (mounted) context.go(R.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                children: [
                  const Center(child: PanditEmblem(height: 72)),
                  const SizedBox(height: 28),
                  Text(t('select_language_title'), style: AppText.heading(size: 28)),
                  const SizedBox(height: 8),
                  Text(t('select_language_subtitle'), style: AppText.body(size: 15, color: AppColors.mutedForeground, height: 1.4)),
                  const SizedBox(height: 24),
                  LanguageList(selected: _selected, onSelect: (c) => setState(() => _selected = c)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: AppButton(label: t('continue'), trailingIcon: LucideIcons.arrowRight, onPressed: _selected == null ? null : _continue),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageList extends StatelessWidget {
  const LanguageList({super.key, required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final l in appLanguages)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LangTile(lang: l, selected: selected == l.code, onTap: () => onSelect(l.code)),
        ),
    ],
  );
}

class _LangTile extends StatelessWidget {
  const _LangTile({required this.lang, required this.selected, required this.onTap});
  final AppLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    decoration: BoxDecoration(
      color: selected ? AppColors.bluntRed.withValues(alpha: .05) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: selected ? AppColors.bluntRed : AppColors.border, width: selected ? 1.6 : 1),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: selected ? AppColors.bluntRed : AppColors.cream, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  lang.letter,
                  style: AppText.body(size: 20, weight: FontWeight.w700, color: selected ? Colors.white : AppColors.bluntRed),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lang.native, style: AppText.body(size: 17, weight: FontWeight.w600)),
                    Text(lang.english, style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: selected ? 1 : 0,
                child: const Icon(LucideIcons.circleCheck, color: AppColors.bluntRed),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Language switcher sheet for signed-in Pandits (Profile → Language).
Future<void> showLanguageSheet(BuildContext context) async {
  var selected = I18n.code;
  await showAppSheet<void>(
    context,
    title: t('select_language_title'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          LanguageList(selected: selected, onSelect: (c) => set(() => selected = c)),
          const SizedBox(height: 8),
          AppButton(
            label: t('continue'),
            onPressed: () async {
              await I18n.change(selected);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}
