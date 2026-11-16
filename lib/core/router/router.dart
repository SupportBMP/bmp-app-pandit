import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/intro_page.dart';
import '../../features/auth/language_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/onboarding_page.dart';
import '../../features/auth/profile_info_page.dart';
import '../../features/auth/referral_page.dart';
import '../../features/auth/splash_page.dart';
import '../../features/auth/waiting_page.dart';
import '../../features/bookings/add_puja_page.dart';
import '../../features/bookings/bookings_page.dart';
import '../../features/bookings/pooja_details_page.dart';
import '../../features/devotees/devotees_page.dart';
import '../../features/devotees/family_members_page.dart';
import '../../features/epuja/epuja_offerings_page.dart';
import '../../features/epuja/epuja_page.dart';
import '../../features/home/home_page.dart';
import '../../features/home/panchang_page.dart';
import '../../features/kundli/kundli_input_page.dart';
import '../../features/kundli/kundli_profiles_page.dart';
import '../../features/kundli/kundli_results_page.dart';
import '../../features/legal/legal_page.dart';
import '../../features/profile/edit_profile_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/subscription_page.dart';
import '../../features/samagri/samagri_add_items_page.dart';
import '../../features/samagri/samagri_list_page.dart';
import '../../features/samagri/samagri_page.dart';
import '../../features/shell/tab_shell.dart';
import '../../features/templates/template_editor_page.dart';
import '../../features/templates/templates_page.dart';
import '../storage/prefs.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

const _publicRoutes = {R.splash, R.language, R.onboarding, R.login, R.legal};

GoRouter buildRouter() => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: R.splash,
  redirect: (context, state) {
    // Signed out (or a 401 cleared the session): back to login.
    final signedIn = Prefs.token != null && Prefs.token!.isNotEmpty;
    if (!signedIn && !_publicRoutes.contains(state.matchedLocation)) return R.login;
    return null;
  },
  routes: [
    GoRoute(path: R.splash, builder: (_, _) => const SplashPage()),
    GoRoute(path: R.language, builder: (_, _) => const LanguagePage()),
    GoRoute(path: R.onboarding, builder: (_, _) => const OnboardingPage()),
    GoRoute(path: R.login, builder: (_, _) => const LoginPage()),
    GoRoute(path: R.referral, builder: (_, _) => const ReferralPage()),
    GoRoute(
      path: R.profileInfo,
      builder: (_, s) => ProfileInfoPage(isReapplication: (s.extra as Map?)?['isReapplication'] == true),
    ),
    GoRoute(path: R.waiting, builder: (_, _) => const WaitingPage()),
    GoRoute(path: R.intro, builder: (_, _) => const IntroPage()),
    GoRoute(path: R.legal, builder: (_, _) => const LegalPage()),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => TabShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: R.home, builder: (_, _) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: R.bookings,
              builder: (_, s) => BookingsPage(args: s.extra),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: R.epuja, builder: (_, _) => const EPujaPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: R.devotees, builder: (_, _) => const DevoteesPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: R.profile, builder: (_, _) => const ProfilePage())],
        ),
      ],
    ),
    _push(R.addPuja, (a) => AddPujaPage(args: a)),
    _push(R.poojaDetails, (a) => PoojaDetailsPage(args: a)),
    _push(R.epujaOfferings, (a) => EPujaOfferingsPage(args: a)),
    _push(R.familyMembers, (a) => FamilyMembersPage(args: a)),
    _push(R.samagri, (a) => const SamagriPage()),
    _push(R.samagriList, (a) => SamagriListPage(args: a)),
    _push(R.samagriAddItems, (a) => SamagriAddItemsPage(args: a)),
    _push(R.editProfile, (a) => const EditProfilePage()),
    _push(R.subscription, (a) => const SubscriptionPage()),
    _push(R.panchang, (a) => PanchangPage(args: a)),
    _push(R.templates, (a) => const TemplatesPage()),
    _push(R.templateEditor, (a) => TemplateEditorPage(args: a)),
    _push(R.kundliProfiles, (a) => const KundliProfilesPage()),
    _push(R.kundliInput, (a) => KundliInputPage(args: a)),
    _push(R.kundliResults, (a) => KundliResultsPage(args: a)),
  ],
);

GoRoute _push(String path, Widget Function(Object? extra) build) =>
    GoRoute(path: path, parentNavigatorKey: rootNavigatorKey, builder: (_, s) => build(s.extra));
