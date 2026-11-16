import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Six OTP boxes over one hidden field (supports SMS autofill / paste).
class OtpBoxes extends StatefulWidget {
  const OtpBoxes({super.key, required this.onChanged, this.length = 6, this.hasError = false});
  final ValueChanged<String> onChanged;
  final int length;
  final bool hasError;

  @override
  State<OtpBoxes> createState() => OtpBoxesState();
}

class OtpBoxesState extends State<OtpBoxes> {
  final _c = TextEditingController();
  final _f = FocusNode();

  void clear() {
    _c.clear();
    setState(() {});
    _f.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _f.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.text;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final size = ((box.maxWidth - gap * (widget.length - 1)) / widget.length).clamp(36.0, 56.0);
        return GestureDetector(
          onTap: () => _f.requestFocus(),
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < widget.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: size,
                      height: size * 1.12,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i < v.length ? Colors.white : AppColors.gray50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          width: (i == v.length && _f.hasFocus) ? 2 : 1,
                          color: widget.hasError
                              ? AppColors.destructive
                              : (i == v.length && _f.hasFocus)
                              ? AppColors.bluntRed
                              : (i < v.length ? AppColors.bluntRed.withValues(alpha: .4) : AppColors.gray200),
                        ),
                      ),
                      child: Text(i < v.length ? v[i] : '', style: AppText.body(size: 22, weight: FontWeight.w700)),
                    ),
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _c,
                    focusNode: _f,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: widget.length,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    onChanged: (s) {
                      setState(() {});
                      widget.onChanged(s);
                    },
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
