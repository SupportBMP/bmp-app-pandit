import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/state/session.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/brand.dart';
import 'auth_flow.dart';

/// Minimal branded splash on the customer app's cream: the Pandit emblem and
/// wordmark fade in while the session is restored, then the app routes by
/// KYC status (Splash.js).
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void initState() {
    super.initState();
    _route();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    final minShow = Future<void>.delayed(const Duration(milliseconds: 1200));
    final session = ref.read(sessionProvider.notifier);
    if (Prefs.token != null && Prefs.token!.isNotEmpty) {
      // Always refresh: KYC status may have changed since the last launch.
      final user = await session.refresh();
      await minShow;
      if (!mounted) return;
      goToDestination(context, user);
      return;
    }
    await minShow;
    if (!mounted) return;
    context.go(Prefs.onboarded ? R.login : R.language);
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.15),
                  radius: .9,
                  colors: [Colors.white, AppColors.cream, AppColors.creamDark.withValues(alpha: .7)],
                  stops: const [0, .6, 1],
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(fade),
                child: const Column(mainAxisSize: MainAxisSize.min, children: [PanditEmblem(height: 132), SizedBox(height: 28), PanditWordmark(width: 190)]),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: SafeArea(
              child: FadeTransition(
                opacity: fade,
                child: Column(
                  children: [
                    const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.bluntRed)),
                    const SizedBox(height: 14),
                    Text('Serving devotees with devotion', style: AppText.body(size: 13, color: AppColors.mutedForeground)),
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
