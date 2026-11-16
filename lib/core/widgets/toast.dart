import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Floating toast (react-native-toast-message replacement), styled like the
/// customer app's toaster.
class Toast {
  Toast._();

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void show(String message) => _show(message, LucideIcons.info, AppColors.blue500);
  static void success(String message) => _show(message, LucideIcons.circleCheck, AppColors.green600);
  static void error(String message) => _show(message, LucideIcons.circleX, AppColors.red500);

  static void _show(String message, IconData icon, Color iconColor) {
    final m = messengerKey.currentState;
    if (m == null || message.isEmpty) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        backgroundColor: Colors.white,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: AppText.body(size: 14, color: AppColors.foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
