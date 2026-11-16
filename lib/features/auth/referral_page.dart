import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

/// Optional referral code for new accounts (ReferralScreen.js).
class ReferralPage extends ConsumerStatefulWidget {
  const ReferralPage({super.key});

  @override
  ConsumerState<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends ConsumerState<ReferralPage> {
  final _c = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _c.text.trim();
    if (code.isEmpty) {
      Toast.error(t('please_enter_referral_code', 'Please enter a referral code'));
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.addReferralCode(code);
      Toast.success(t('referral_applied', 'Referral applied successfully'));
      if (!mounted) return;
      final seen = boolOf(ref.read(sessionProvider)?['hasSeenIntroduction']);
      context.go(seen ? R.home : R.intro);
    } catch (e) {
      Toast.error(apiError(e, t('unable_to_apply_referral', 'Unable to apply referral')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.creamDark),
            ),
            child: const Icon(LucideIcons.gift, size: 32, color: AppColors.bluntRed),
          ),
          const SizedBox(height: 24),
          Text(t('enter_referral_code'), style: AppText.body(size: 26, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(t('enter_referral_code_info'), style: AppText.body(size: 15, color: AppColors.mutedForeground, height: 1.4)),
          const SizedBox(height: 28),
          AppTextField(controller: _c, label: t('referral_code'), textCapitalization: TextCapitalization.characters, autofocus: true),
          const SizedBox(height: 24),
          AppButton(label: t('apply_referral'), loading: _loading, trailingIcon: LucideIcons.arrowRight, onPressed: _apply),
          const SizedBox(height: 12),
          AppButton(label: t('skip'), kind: BtnKind.outline, onPressed: _loading ? null : () => context.go(R.intro)),
        ],
      ),
    ),
  );
}
