import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/ui.dart';

/// Four-slide welcome carousel shown once before login (OnboardingSlides.js).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pc = PageController();
  int _i = 0;

  List<(String, String, String)> get _slides => [
    (t('welcome_pandit'), t('welcome_pandit_subtitle'), 'assets/images/welcome_pandit_ji.png'),
    (t('conduct_online_pujas_title'), t('conduct_online_pujas_desc'), 'assets/images/online_puja.png'),
    (t('grow_client_base_title'), t('grow_client_base_desc'), 'assets/images/increase_customer_base.png'),
    (t('serve_devotees_title'), t('serve_devotees_desc'), 'assets/images/serve_devotees.png'),
  ];

  Future<void> _finish() async {
    await Prefs.setOnboarded();
    if (mounted) context.go(R.login);
  }

  void _next() {
    if (_i < _slides.length - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final last = _i == slides.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(onPressed: last ? null : _finish, child: Text(t('skip'))),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) {
                  final (title, desc, img) = slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: AppColors.creamDark),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(img, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(title, textAlign: TextAlign.center, style: AppText.heading(size: 28)),
                        const SizedBox(height: 10),
                        Text(
                          desc,
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 15, color: AppColors.mutedForeground, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(color: i == _i ? AppColors.bluntRed : AppColors.gray200, borderRadius: BorderRadius.circular(4)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  if (_i > 0) ...[
                    SizedBox(
                      width: 56,
                      child: AppButton(
                        label: '',
                        icon: LucideIcons.arrowLeft,
                        kind: BtnKind.outline,
                        onPressed: () => _pc.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: AppButton(label: last ? t('start') : t('next'), trailingIcon: last ? null : LucideIcons.arrowRight, onPressed: _next),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
