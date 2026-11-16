import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/ui.dart';

/// In-app privacy policy (bundled Markdown) with a link to the live page.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, this.args});
  final Object? args;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: appBar(
      context,
      t('privacy_policy', 'Privacy policy'),
      actions: [
        IconButton(
          tooltip: t('open_in_browser', 'Open in browser'),
          onPressed: () => launchUrl(Uri.parse('https://bookmypoojaonline.com/privacy-policy'), mode: LaunchMode.externalApplication),
          icon: const Icon(LucideIcons.externalLink, size: 20),
        ),
      ],
    ),
    body: FutureBuilder<String>(
      future: rootBundle.loadString('assets/i18n/privacy_policy.md'),
      builder: (_, s) {
        if (!s.hasData) return const AppLoader();
        return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [for (final line in s.data!.split('\n')) _line(line)]);
      },
    ),
  );

  Widget _line(String l) {
    final s = l.trim();
    if (s.isEmpty) return const SizedBox(height: 8);
    if (s.startsWith('# '))
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s.substring(2), style: AppText.heading(size: 24)),
      );
    if (s.startsWith('## '))
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(s.substring(3), style: AppText.body(size: 18, weight: FontWeight.w700)),
      );
    if (s.startsWith('### '))
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(s.substring(4), style: AppText.body(size: 15, weight: FontWeight.w700)),
      );
    final bullet = s.startsWith('- ');
    final body = (bullet ? s.substring(2) : s);
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var i = 0;
    for (final m in re.allMatches(body)) {
      spans.add(TextSpan(text: body.substring(i, m.start)));
      spans.add(
        TextSpan(
          text: m[1],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      i = m.end;
    }
    spans.add(TextSpan(text: body.substring(i)));
    final text = Text.rich(
      TextSpan(children: spans),
      style: AppText.body(size: 14, height: 1.5, color: AppColors.foreground),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: bullet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7, right: 8),
                  child: CircleAvatar(radius: 2.5, backgroundColor: AppColors.bluntRed),
                ),
                Expanded(child: text),
              ],
            )
          : text,
    );
  }
}
