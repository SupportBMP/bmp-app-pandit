import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import 'auth_flow.dart';

/// KYC pending / rejected screen (WaitingForApproval.js). Re-checks the
/// status on open and on "Check status"; a rejected Pandit can edit and
/// resubmit.
class WaitingPage extends ConsumerStatefulWidget {
  const WaitingPage({super.key});

  @override
  ConsumerState<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends ConsumerState<WaitingPage> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(silent: true));
  }

  Future<void> _check({bool silent = false}) async {
    setState(() => _checking = true);
    final user = await ref.read(sessionProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _checking = false);
    if (str(user?['KYCStatus']) == 'approved') goToDestination(context, user);
  }

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).signOut();
    if (mounted) context.go(R.login);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final rejected = str(user?['KYCStatus']) == 'rejected';
    final reason = str(user?['rejectionReason']);
    final (accent, bg, icon) = rejected
        ? (AppColors.red600, AppColors.red50, LucideIcons.circleX)
        : (AppColors.amber600, AppColors.amber50, LucideIcons.hourglass);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.bluntRed,
          onRefresh: _check,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  const PanditLockup(height: 34),
                  const Spacer(),
                  TextButton.icon(onPressed: _logout, icon: const Icon(LucideIcons.logOut, size: 16), label: Text(t('logout', 'Logout'))),
                ],
              ),
              const SizedBox(height: 28),
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                      child: Icon(icon, size: 38, color: accent),
                    ),
                    const SizedBox(height: 20),
                    Text(rejected ? t('application_rejected') : t('waiting_for_approval'), textAlign: TextAlign.center, style: AppText.heading(size: 24)),
                    const SizedBox(height: 10),
                    Text(
                      rejected ? t('your_application_has_been_rejected') : t('we_have_received_your_details'),
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 15, color: AppColors.mutedForeground, height: 1.5),
                    ),
                    if (!rejected) ...[
                      const SizedBox(height: 8),
                      Text(
                        t('once_verified_you_will_get_access'),
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 14, color: AppColors.mutedForeground, height: 1.5),
                      ),
                    ],
                    if (rejected) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.red50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.red100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('reason_for_rejection', 'Reason for rejection'),
                              style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.red700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reason.isNotEmpty ? reason : t('please_review_and_update_your_profile'),
                              style: AppText.body(size: 14, color: AppColors.foreground, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: t('edit_profile'),
                        icon: LucideIcons.squarePen,
                        onPressed: () => context.push(R.profileInfo, extra: {'isReapplication': true}),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.info, size: 18, color: AppColors.saffronDark),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t('profile_under_review_note', 'Your profile is under review. You can edit it again only if the review asks for changes.'),
                                style: AppText.body(size: 13, color: AppColors.mutedForeground, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                onTap: () => launchUrl(Uri.parse('tel:${Env.supportPhone}')),
                child: Row(
                  children: [
                    const IconPill(icon: LucideIcons.phone),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('for_support_please_call'), style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                          Text(
                            Env.supportPhone,
                            style: AppText.body(size: 18, weight: FontWeight.w700, color: AppColors.bluntRed),
                          ),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, color: AppColors.gray400),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppButton(label: t('check_status'), kind: BtnKind.secondary, icon: LucideIcons.refreshCw, loading: _checking, onPressed: _check),
            ],
          ),
        ),
      ),
    );
  }
}
