import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/config/env.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/otp.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import 'auth_flow.dart';

/// Sign in / sign up with mobile OTP, laid out like the customer app's auth
/// page: phone step → OTP step on one screen (LoginS.js + Verify.js).
/// A first-time number becomes a new account; the KYC profile form follows.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _resendSeconds = 59;

  final _otpKey = GlobalKey<OtpBoxesState>();
  String _phone = '';
  String _callingCode = '91';
  String _flag = '🇮🇳';
  bool _otpStep = false;
  String _otp = '';
  bool _loading = false;
  String? _error;
  int _countdown = _resendSeconds;
  Timer? _timer;

  bool get _validPhone => _callingCode == '91' ? RegExp(r'^[6-9]\d{9}$').hasMatch(_phone) : _phone.length >= 6;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  Future<void> _sendOtp() async {
    if (!_validPhone) {
      setState(() => _error = t('enter_valid_phone', 'Please enter a valid phone number'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Api.sendPhoneOtp(_phone, _callingCode);
      Toast.success(t('otp_sent', 'OTP sent'));
      setState(() {
        _otpStep = true;
        _otp = '';
      });
      _startCountdown();
    } catch (e) {
      final msg = apiError(e, t('otp_not_sent', 'OTP not sent'));
      setState(() => _error = msg);
      Toast.error(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await Api.resendPhoneOtp(_phone, _callingCode);
      Toast.success(t('otp_sent', 'OTP sent'));
    } catch (_) {}
    _otpKey.currentState?.clear();
    setState(() {
      _otp = '';
      _error = null;
    });
    _startCountdown();
  }

  Future<void> _verify() async {
    if (_otp.length != 6 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Api.verifyPhoneOtp(_phone, _callingCode, _otp);
      final body = obj(res.data);
      final user = obj(body['user']);
      final token = str(body['token']);
      await ref.read(sessionProvider.notifier).signIn(token, user);
      Toast.success(t('verified_successfully', 'Verified successfully'));
      if (!mounted) return;
      goToDestination(context, user, isNewAccount: res.statusCode == 201);
    } catch (e) {
      final msg = apiError(e, t('error_verifying_otp', 'Error verifying OTP'));
      Toast.error(msg);
      _otpKey.currentState?.clear();
      setState(() {
        _error = msg;
        _otp = '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _otpStep = false;
      _otp = '';
      _error = null;
    });
  }

  void _pickCountry() => showCountryPicker(
    context: context,
    showPhoneCode: true,
    favorite: const ['IN', 'US', 'GB', 'AE', 'SG', 'AU', 'CA'],
    countryListTheme: CountryListThemeData(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      bottomSheetHeight: MediaQuery.sizeOf(context).height * .75,
      inputDecoration: appInputDecoration(hint: t('search', 'Search'), prefix: const Icon(LucideIcons.search, size: 18)),
    ),
    onSelect: (c) => setState(() {
      _callingCode = c.phoneCode;
      _flag = c.flagEmoji;
      _error = null;
    }),
  );

  @override
  Widget build(BuildContext context) {
    final title = _otpStep ? t('verify_otp') : t('welcome_pandit_ji', 'Welcome, Pandit Ji');
    final subtitle = _otpStep
        ? '${t('otp_sent_to')} +$_callingCode $_phone'
        : t('login_subtitle', 'Sign in or create your Pandit account with your mobile number.');

    return PopScope(
      canPop: !_otpStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _otpStep) _changeNumber();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 56,
                          child: _otpStep
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(icon: Icon(Icons.adaptive.arrow_back), onPressed: _changeNumber),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        const Center(child: PanditEmblem(height: 84)),
                        const SizedBox(height: 14),
                        const Center(child: PanditWordmark(width: 150)),
                        const SizedBox(height: 36),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Column(
                            key: ValueKey(_otpStep),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppText.body(size: 26, weight: FontWeight.w700, letterSpacing: -.3)),
                              const SizedBox(height: 8),
                              Text(subtitle, style: AppText.body(size: 15, color: AppColors.mutedForeground, height: 1.4)),
                              const SizedBox(height: 28),
                              _otpStep ? _otpView() : _phoneView(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          t('login_legal', 'By continuing, you agree to the BookMyPooja Partner Terms & Privacy Policy.'),
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 12, color: AppColors.mutedForeground, height: 1.5),
                        ),
                        TextButton(
                          onPressed: () => context.push(R.legal),
                          child: Text(
                            t('privacy_policy', 'Privacy Policy'),
                            style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.bluntRed),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => launchUrl(Uri.parse('tel:${Env.supportPhone}')),
                          icon: const Icon(LucideIcons.phone, size: 16),
                          label: Text('${t('need_help', 'Need help?')} ${Env.supportPhone}'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        autofocus: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        maxLength: _callingCode == '91' ? 10 : 15,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) => setState(() {
          _phone = v;
          _error = null;
        }),
        onSubmitted: (_) => _validPhone ? _sendOtp() : null,
        style: AppText.body(size: 18, weight: FontWeight.w600, letterSpacing: 1.2),
        decoration: appInputDecoration(label: t('mobile_number'), error: _error).copyWith(
          prefixIcon: InkWell(
            onTap: _pickCountry,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_flag  +$_callingCode', style: AppText.body(size: 18, weight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.mutedForeground),
                  Container(margin: const EdgeInsets.only(left: 8), width: 1, height: 24, color: AppColors.gray200),
                ],
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: _validPhone ? const Icon(Icons.check_circle, color: AppColors.green600) : null,
        ),
      ),
      const SizedBox(height: 8),
      Text(t('otp_info'), style: AppText.body(size: 13, color: AppColors.mutedForeground)),
      const SizedBox(height: 24),
      AppButton(label: t('send_otp'), loading: _loading, trailingIcon: LucideIcons.arrowRight, onPressed: _validPhone ? _sendOtp : null),
    ],
  );

  Widget _otpView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        t('enter_otp'),
        style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.mutedForeground),
      ),
      const SizedBox(height: 12),
      OtpBoxes(
        key: _otpKey,
        hasError: _error != null,
        onChanged: (v) {
          setState(() {
            _otp = v;
            _error = null;
          });
          if (v.length == 6) _verify();
        },
      ),
      if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: AppText.body(size: 13, color: AppColors.destructive))],
      const SizedBox(height: 14),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(t('didnt_get_code', "Didn't get the code?"), style: AppText.body(size: 14, color: AppColors.mutedForeground)),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _countdown > 0 || _loading ? null : _resend,
            child: Text(_countdown > 0 ? '${t('resend_in')} ${_countdown}s' : t('resend_otp')),
          ),
        ],
      ),
      const SizedBox(height: 12),
      AppButton(label: t('verify_otp'), loading: _loading, onPressed: _otp.length == 6 ? _verify : null),
      const SizedBox(height: 8),
      TextButton(onPressed: _loading ? null : _changeNumber, child: Text(t('change_number'))),
    ],
  );
}
