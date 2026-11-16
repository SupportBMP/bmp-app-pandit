import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// (icon, label key) for the five tabs, in order.
const tabItems = <(IconData, String)>[
  (LucideIcons.house, 'nav_home'),
  (LucideIcons.calendarCheck, 'nav_bookings'),
  (LucideIcons.video, 'nav_epuja'),
  (LucideIcons.users, 'nav_devotees'),
  (LucideIcons.user, 'nav_profile'),
];

/// Bottom-tab scaffold (TabBarNavigation.js). Each tab keeps its own stack.
class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < tabItems.length; i++)
                  Expanded(
                    child: _TabButton(
                      icon: tabItems[i].$1,
                      label: t(tabItems[i].$2),
                      selected: shell.currentIndex == i,
                      onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          decoration: BoxDecoration(color: selected ? AppColors.bluntRed.withValues(alpha: .1) : Colors.transparent, borderRadius: BorderRadius.circular(999)),
          child: Icon(icon, size: 22, color: selected ? AppColors.bluntRed : AppColors.gray500),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(size: 11.5, weight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.bluntRed : AppColors.gray500),
        ),
      ],
    ),
  );
}
