import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/ui.dart';
import '../shell/tab_shell.dart';

/// First-run tour of the five tabs (IntroductionSlides.js). Finishing or
/// skipping marks `hasSeenIntroduction` on the server.
class IntroPage extends ConsumerStatefulWidget {
  const IntroPage({super.key});

  @override
  ConsumerState<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends ConsumerState<IntroPage> {
  int _step = 0;
  bool _closing = false;

  List<(String, String)> get _steps => [
    (t('intro_welcome'), t('intro_subtitle')),
    (t('your_dashboard'), t('your_dashboard_desc')),
    (t('booking_management'), t('manage_bookings_desc')),
    (t('epuja_management'), t('epuja_management_desc')),
    (t('devotee_management'), t('devotee_management_desc')),
    (t('profile_settings'), t('profile_settings_desc')),
  ];

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
      await Api.updateProfile({'hasSeenIntroduction': true});
    } catch (_) {}
    await ref.read(sessionProvider.notifier).refresh();
    if (mounted) context.go(R.home);
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final (title, desc) = steps[_step];
    final last = _step == steps.length - 1;
    final highlighted = _step - 1;

    return Scaffold(
      backgroundColor: AppColors.maroonDark,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.saffron, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(LucideIcons.lightbulb, size: 18, color: Colors.white),
                              ),
                              const Spacer(),
                              Text(
                                '${_step + 1} / ${steps.length}',
                                style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.mutedForeground),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(title, style: AppText.heading(size: 24)),
                          const SizedBox(height: 10),
                          Text(desc, style: AppText.body(size: 15, color: AppColors.mutedForeground, height: 1.5)),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_step + 1) / steps.length,
                              minHeight: 6,
                              backgroundColor: AppColors.gray100,
                              color: AppColors.bluntRed,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              if (_step > 0) IconButton.outlined(onPressed: () => setState(() => _step--), icon: const Icon(LucideIcons.arrowLeft, size: 18)),
                              const Spacer(),
                              TextButton(onPressed: _closing ? null : _close, child: Text(t('skip'))),
                              const SizedBox(width: 8),
                              AppButton(
                                label: last ? t('complete') : t('next'),
                                trailingIcon: last ? LucideIcons.check : LucideIcons.arrowRight,
                                expand: false,
                                compact: true,
                                loading: _closing,
                                onPressed: last ? _close : () => setState(() => _step++),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Faux tab bar highlighting the tab each step describes.
          Container(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 68,
                child: Row(
                  children: [
                    for (var i = 0; i < tabItems.length; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: i == highlighted ? AppColors.bluntRed.withValues(alpha: .1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: i == highlighted ? Border.all(color: AppColors.bluntRed, width: 1.5) : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(tabItems[i].$1, size: 22, color: i == highlighted ? AppColors.bluntRed : AppColors.gray400),
                              const SizedBox(height: 4),
                              Text(
                                t(tabItems[i].$2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(size: 11, weight: FontWeight.w600, color: i == highlighted ? AppColors.bluntRed : AppColors.gray400),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
