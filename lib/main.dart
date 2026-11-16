import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/api/api_client.dart';
import 'core/i18n/i18n.dart';
import 'core/notifications/push.dart';
import 'core/router/router.dart';
import 'core/router/routes.dart';
import 'core/storage/prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/toast.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Prefs.init();
  await I18n.init();
  await Push.init();
  runApp(const ProviderScope(child: PanditApp()));
}

class PanditApp extends ConsumerStatefulWidget {
  const PanditApp({super.key});

  @override
  ConsumerState<PanditApp> createState() => _PanditAppState();
}

class _PanditAppState extends ConsumerState<PanditApp> {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    ApiClient.onUnauthorized = () => _router.go(R.login);
    Push.navigate = (path, extra) {
      if (R.tabs.contains(path)) {
        _router.go(path, extra: extra);
      } else {
        _router.push(path, extra: extra);
      }
    };
    I18n.notifier.addListener(_onLanguageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Push.requestPermission();
      await Push.handleInitialMessage();
    });
  }

  /// Language switches apply live (the RN app restarted itself): every
  /// mounted screen rebuilds so `t(...)` picks up the new strings.
  void _onLanguageChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      if (mounted) (context as Element).visitChildren(rebuild);
    });
  }

  @override
  void dispose() {
    I18n.notifier.removeListener(_onLanguageChanged);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'BookMyPooja Partner',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    scaffoldMessengerKey: Toast.messengerKey,
    routerConfig: _router,
    locale: Locale(I18n.code),
    supportedLocales: appLanguages.map((l) => Locale(l.code)),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    builder: (context, child) => MediaQuery(
      // Keep layouts intact on phones set to very large accessibility text.
      data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3)),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
