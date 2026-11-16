import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// The Pandit logo: a meditating Pandit with tilak, seated on the
/// BookMyPooja diya inside its halo rings (square, rounded corners).
class PanditEmblem extends StatelessWidget {
  const PanditEmblem({super.key, this.height = 64});
  final double height;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/brand/logo.png', height: height, width: height, filterQuality: FilterQuality.medium);
}

/// "BOOK MY Pooja" wordmark with the "PARTNER" tag beneath.
class PanditWordmark extends StatelessWidget {
  const PanditWordmark({super.key, this.width = 160, this.color = AppColors.bluntRed, this.tagColor = AppColors.saffronDark});
  final double width;
  final Color color;
  final Color tagColor;

  @override
  Widget build(BuildContext context) {
    final rule = Expanded(child: Container(height: 1, color: tagColor.withValues(alpha: .5)));
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/brand/wordmark.svg',
            width: width,
            colorFilter: color == AppColors.bluntRed ? null : ColorFilter.mode(color, BlendMode.srcIn),
          ),
          SizedBox(height: width * .02),
          Row(
            children: [
              rule,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width * .05),
                child: Text(
                  'PARTNER',
                  style: AppText.body(size: width * .085, weight: FontWeight.w700, color: tagColor, letterSpacing: width * .03),
                ),
              ),
              rule,
            ],
          ),
        ],
      ),
    );
  }
}

/// Emblem + wordmark side by side, for headers.
class PanditLockup extends StatelessWidget {
  const PanditLockup({super.key, this.height = 40});
  final double height;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PanditEmblem(height: height),
      SizedBox(width: height * .22),
      PanditWordmark(width: height * 2.4),
    ],
  );
}
