import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../i18n/i18n.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/format.dart';
import 'brand.dart';

// ═════════════════════════════════════════════════════════════════════════
// Buttons
// ═════════════════════════════════════════════════════════════════════════

enum BtnKind { primary, secondary, outline, ghost, danger, success }

/// The customer app's auth CTA: 54 px, radius 14, blunt red.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = BtnKind.primary,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      BtnKind.primary => (AppColors.bluntRed, Colors.white, null),
      BtnKind.secondary => (AppColors.bluntRed.withValues(alpha: .08), AppColors.bluntRed, null),
      BtnKind.outline => (Colors.white, AppColors.foreground, AppColors.border),
      BtnKind.ghost => (Colors.transparent, AppColors.bluntRed, null),
      BtnKind.danger => (AppColors.red600, Colors.white, null),
      BtnKind.success => (AppColors.green600, Colors.white, null),
    };
    final h = compact ? 40.0 : height;
    final disabled = onPressed == null || loading;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        else ...[
          if (icon != null) ...[Icon(icon, size: compact ? 16 : 18, color: fg), if (label.isNotEmpty) const SizedBox(width: 8)],
          if (label.isNotEmpty)
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: compact ? 14 : 16, weight: FontWeight.w600, color: fg),
              ),
            ),
          if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, size: compact ? 16 : 18, color: fg)],
        ],
      ],
    );
    return Opacity(
      opacity: disabled && !loading ? .45 : 1,
      child: SizedBox(
        height: h,
        width: expand ? double.infinity : null,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 10 : 14),
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Round tinted icon button (header actions, card actions).
class IconPill extends StatelessWidget {
  const IconPill({super.key, required this.icon, this.onTap, this.color = AppColors.bluntRed, this.size = 40, this.tooltip, this.badge});
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final String? tooltip;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    Widget w = Material(
      color: color.withValues(alpha: .08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * .48, color: color),
        ),
      ),
    );
    if (badge != null && badge! > 0) {
      w = Badge(label: Text('$badge'), backgroundColor: AppColors.bluntRed, child: w);
    }
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Inputs
// ═════════════════════════════════════════════════════════════════════════

InputDecoration appInputDecoration({String? label, String? hint, Widget? prefix, Widget? suffix, String? error, bool dense = false}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: error,
    errorMaxLines: 3,
    filled: true,
    fillColor: AppColors.gray50,
    isDense: dense,
    counterText: '',
    labelStyle: AppText.body(size: 15, color: AppColors.mutedForeground),
    floatingLabelStyle: AppText.body(size: 15, color: AppColors.bluntRed, weight: FontWeight.w500),
    hintStyle: AppText.body(size: 15, color: AppColors.gray400),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 12 : 16),
    prefixIcon: prefix,
    suffixIcon: suffix,
    border: b(AppColors.gray200),
    enabledBorder: b(AppColors.gray200),
    disabledBorder: b(AppColors.gray100),
    focusedBorder: b(AppColors.bluntRed, 2),
    errorBorder: b(AppColors.destructive),
    focusedErrorBorder: b(AppColors.destructive, 2),
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.error,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.digitsOnly = false,
    this.textCapitalization = TextCapitalization.none,
    this.initialValue,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.required = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final String? error;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool digitsOnly;
  final TextCapitalization textCapitalization;
  final String? initialValue;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool required;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    initialValue: controller == null ? initialValue : null,
    onChanged: onChanged,
    keyboardType: keyboardType ?? (maxLines > 1 ? TextInputType.multiline : null),
    maxLines: maxLines,
    minLines: minLines,
    maxLength: maxLength,
    enabled: enabled,
    readOnly: readOnly,
    onTap: onTap,
    autofocus: autofocus,
    textInputAction: textInputAction,
    onFieldSubmitted: onSubmitted,
    textCapitalization: textCapitalization,
    inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
    style: AppText.body(size: 16),
    decoration: appInputDecoration(label: label == null ? null : (required ? '$label *' : label), hint: hint, prefix: prefix, suffix: suffix, error: error),
  );
}

/// A read-only field that opens a picker (dropdown, date, time).
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = LucideIcons.chevronDown,
    this.required = false,
    this.error,
    this.enabled = true,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;
  final IconData icon;
  final bool required;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: enabled ? onTap : null,
    child: InputDecorator(
      isEmpty: value == null || value!.isEmpty,
      decoration: appInputDecoration(
        label: required ? '$label *' : label,
        suffix: Icon(icon, size: 18, color: AppColors.mutedForeground),
        error: error,
      ),
      child: Text(value ?? '', style: AppText.body(size: 16, color: enabled ? AppColors.foreground : AppColors.gray400)),
    ),
  );
}

/// Selectable chip (CChip): outlined, maroon tint when selected.
class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.bluntRed.withValues(alpha: .08) : Colors.white,
    shape: StadiumBorder(
      side: BorderSide(color: selected ? AppColors.bluntRed : AppColors.border, width: selected ? 1.4 : 1),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(LucideIcons.check, size: 14, color: AppColors.bluntRed),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.mutedForeground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppText.body(size: 14, weight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? AppColors.bluntRed : AppColors.foreground),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Horizontal filter tabs (All / Pending / Accepted …).
class FilterTabs extends StatelessWidget {
  const FilterTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });
  final List<(String, String)> items; // (value, label)
  final String selected;
  final ValueChanged<String> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.separated(
      padding: padding,
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final (v, l) = items[i];
        final on = v == selected;
        return Material(
          color: on ? AppColors.bluntRed : Colors.white,
          shape: StadiumBorder(side: BorderSide(color: on ? AppColors.bluntRed : AppColors.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onChanged(v),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  l,
                  style: AppText.body(size: 14, weight: FontWeight.w600, color: on ? Colors.white : AppColors.foreground),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// Surfaces
// ═════════════════════════════════════════════════════════════════════════

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = Colors.white,
    this.margin,
    this.borderColor = AppColors.border,
    this.radius = 16,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsets? margin;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: [BoxShadow(color: AppColors.maroon.withValues(alpha: .04), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

/// Section title with an optional leading icon and trailing action.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.icon, this.action, this.onAction, this.subtitle});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: AppColors.bluntRed.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: AppColors.bluntRed),
        ),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.body(size: 17, weight: FontWeight.w700)),
            if (subtitle != null) Text(subtitle!, style: AppText.body(size: 13, color: AppColors.mutedForeground)),
          ],
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          child: Text(
            action!,
            style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.bluntRed),
          ),
        ),
    ],
  );
}

/// Screen heading in the customer app's style: Playfair title with a
/// highlighted word.
class HeroHeading extends StatelessWidget {
  const HeroHeading({super.key, required this.title, this.highlight, this.size = 26, this.align = TextAlign.start});
  final String title;
  final String? highlight;
  final double size;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: title),
        if (highlight != null) ...[
          const TextSpan(text: ' '),
          TextSpan(
            text: highlight,
            style: const TextStyle(color: AppColors.primary),
          ),
        ],
      ],
    ),
    textAlign: align,
    style: AppText.heading(size: size),
  );
}

/// Inline key/value row inside cards.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.text, this.color = AppColors.mutedForeground, this.maxLines = 2});
  final IconData icon;
  final String text;
  final Color color;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 14, color: color),
          ),
        ),
      ],
    ),
  );
}

/// Booking / KYC / certificate status pill.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.label});
  final String status;
  final String? label;

  static (Color, Color) colorsFor(String s) => switch (s.toLowerCase()) {
    'pending' || 'requested' || 'scheduled' || 'upcoming' => (AppColors.amber700, AppColors.amber50),
    'accepted' || 'approved' || 'confirmed' || 'active' || 'live' || 'paid' => (AppColors.green700, AppColors.green50),
    'completed' || 'ended' => (AppColors.slate700, AppColors.slate100),
    'cancelled' || 'canceled' || 'rejected' || 'declined' || 'expired' => (AppColors.red700, AppColors.red50),
    _ => (AppColors.blue700, AppColors.blue50),
  };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = colorsFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label ?? capitalize(status),
        style: AppText.body(size: 12, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.url, this.name, this.size = 48});
  final String? url;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.bluntRed.withValues(alpha: .1), shape: BoxShape.circle),
      child: Text(
        initials(name),
        style: AppText.body(size: size * .36, weight: FontWeight.w700, color: AppColors.bluntRed),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.width, this.height, this.fit = BoxFit.cover, this.radius = 0});
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ph = Container(
      width: width,
      height: height,
      color: AppColors.muted,
      child: const Icon(LucideIcons.image, color: AppColors.gray300),
    );
    final img = (url == null || url!.isEmpty)
        ? ph
        : CachedNetworkImage(imageUrl: url!, width: width, height: height, fit: fit, placeholder: (_, _) => ph, errorWidget: (_, _, _) => ph);
    return radius == 0 ? img : ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }
}

// ═════════════════════════════════════════════════════════════════════════
// States
// ═════════════════════════════════════════════════════════════════════════

/// The app loader: the Pandit emblem breathing (as the customer app does
/// with its diya).
class AppLoader extends StatefulWidget {
  const AppLoader({super.key, this.size = 44, this.message});
  final double size;
  final String? message;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final v = Curves.easeInOut.transform(_c.value);
            return Opacity(
              opacity: .55 + .45 * v,
              child: Transform.scale(scale: .9 + .1 * v, child: child),
            );
          },
          child: PanditEmblem(height: widget.size),
        ),
        if (widget.message != null) ...[const SizedBox(height: 14), Text(widget.message!, style: AppText.body(size: 14, color: AppColors.mutedForeground))],
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon = LucideIcons.inbox, this.action, this.onAction, this.compact = false});
  final String title;
  final String? message;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 20 : 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 56 : 72,
            height: compact ? 56 : 72,
            decoration: BoxDecoration(
              color: AppColors.cream,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.creamDark),
            ),
            child: Icon(icon, size: compact ? 24 : 30, color: AppColors.bluntRed),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.body(size: 17, weight: FontWeight.w700),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppText.body(size: 14, color: AppColors.mutedForeground, height: 1.4),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 20),
            AppButton(label: action!, onPressed: onAction, expand: false, compact: true, icon: LucideIcons.plus),
          ],
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.red50, shape: BoxShape.circle),
            child: const Icon(LucideIcons.cloudOff, size: 30, color: AppColors.red600),
          ),
          const SizedBox(height: 16),
          Text(t('something_went_wrong', 'Something went wrong'), style: AppText.body(size: 17, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            message ?? t('please_try_again', 'Please check your connection and try again.'),
            textAlign: TextAlign.center,
            style: AppText.body(size: 14, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          AppButton(label: t('retry', 'Retry'), onPressed: onRetry, expand: false, compact: true, icon: LucideIcons.refreshCw, kind: BtnKind.secondary),
        ],
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// Page chrome
// ═════════════════════════════════════════════════════════════════════════

/// White app bar used on every pushed screen.
PreferredSizeWidget appBar(BuildContext context, String title, {List<Widget>? actions, Widget? leading, PreferredSizeWidget? bottom, String? subtitle}) =>
    AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: AppColors.foreground,
      elevation: 0,
      scrolledUnderElevation: .5,
      shadowColor: AppColors.border,
      centerTitle: false,
      leading: leading,
      titleSpacing: leading == null && !Navigator.of(context).canPop() ? 16 : 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.body(size: 18, weight: FontWeight.w700)),
          if (subtitle != null) Text(subtitle, style: AppText.body(size: 12, color: AppColors.mutedForeground)),
        ],
      ),
      actions: [...?actions, const SizedBox(width: 8)],
      bottom: bottom,
    );

/// Background used behind lists: the customer app's warm off-white.
const pageBg = Color(0xFFFAF8F5);

// ═════════════════════════════════════════════════════════════════════════
// Dialogs & sheets
// ═════════════════════════════════════════════════════════════════════════

Future<bool> confirmDialog(BuildContext context, {required String title, String? message, String? confirm, bool destructive = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: AppText.body(size: 18, weight: FontWeight.w700)),
      content: message == null ? null : Text(message, style: AppText.body(size: 15, color: AppColors.mutedForeground, height: 1.4)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(label: t('cancel', 'Cancel'), kind: BtnKind.outline, compact: true, onPressed: () => Navigator.pop(ctx, false)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: confirm ?? t('confirm', 'Confirm'),
                kind: destructive ? BtnKind.danger : BtnKind.primary,
                compact: true,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return r == true;
}

/// Rounded bottom sheet with a title, used for forms and details.
Future<T?> showAppSheet<T>(BuildContext context, {required String title, required WidgetBuilder builder, bool expand = false}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * (expand ? .92 : .85)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: AppText.body(size: 19, weight: FontWeight.w700)),
                ),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x, size: 20)),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(child: Builder(builder: builder)),
        ],
      ),
    ),
  ),
);

/// Action sheet with icon rows (image vs document, edit vs delete …).
Future<T?> showActionSheet<T>(BuildContext context, {String? title, required List<(T, IconData, String)> actions}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: Colors.white,
  showDragHandle: true,
  useSafeArea: true,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
  builder: (ctx) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(title, style: AppText.body(size: 17, weight: FontWeight.w700)),
        ),
      for (final (v, icon, label) in actions)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: Icon(icon, color: AppColors.bluntRed),
          title: Text(label, style: AppText.body(size: 16)),
          onTap: () => Navigator.pop(ctx, v),
        ),
      const SizedBox(height: 12),
    ],
  ),
);
