/// Route paths. Each one maps from the React Native route name it replaces
/// (see [legacyRouteNames]) so push-notification payloads that carry
/// `data.route = "BookingsTab"` etc. keep working.
class R {
  R._();

  // Auth / onboarding
  static const splash = '/splash';
  static const language = '/language';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const verify = '/verify';
  static const referral = '/referral';
  static const profileInfo = '/profile-info';
  static const waiting = '/waiting';
  static const intro = '/intro';

  // Tabs
  static const home = '/home';
  static const bookings = '/bookings';
  static const epuja = '/epuja';
  static const devotees = '/devotees';
  static const profile = '/profile';

  // Pushed screens
  static const addPuja = '/add-puja';
  static const poojaDetails = '/pooja-details';
  static const epujaOfferings = '/epuja-offerings';
  static const familyMembers = '/family-members';
  static const samagri = '/samagri';
  static const samagriList = '/samagri-list';
  static const samagriAddItems = '/samagri-add-items';
  static const editProfile = '/edit-profile';
  static const panchang = '/panchang';
  static const templates = '/templates';
  static const templateEditor = '/template-editor';
  static const kundliProfiles = '/kundli';
  static const kundliInput = '/kundli/input';
  static const kundliResults = '/kundli/results';
  static const subscription = '/subscription';
  static const legal = '/legal';

  static const tabs = [home, bookings, epuja, devotees, profile];
}

/// React Navigation route name → path, for notification routing.
const legacyRouteNames = <String, String>{
  'HomeTab': R.home,
  'BookingsTab': R.bookings,
  'CalendarTab': R.bookings,
  'EPujaTab': R.epuja,
  'ClientsTab': R.devotees,
  'CustomersTab': R.devotees,
  'ProfileTab': R.profile,
  'OptionsTab': R.profile,
  'TabBar': R.home,
  'Splash': R.splash,
  'Auth': R.login,
  'Login': R.login,
  'LoginS': R.login,
  'Register': R.login,
  'Verify': R.login,
  'OtpVerification': R.login,
  'LanguageSelection': R.language,
  'OnboardingSlides': R.onboarding,
  'IntroductionSlides': R.intro,
  'ReferralScreen': R.referral,
  'ProfileInformation': R.profileInfo,
  'WaitingForApproval': R.waiting,
  'ProfileUpdate': R.editProfile,
  'EditProfile': R.editProfile,
  'AddPuja': R.addPuja,
  'PoojaDetailsScreen': R.poojaDetails,
  'EPujaOfferingsScreen': R.epujaOfferings,
  'FamilyMembers': R.familyMembers,
  'Samagri': R.samagri,
  'SamagriList': R.samagriList,
  'SamagriAddItems': R.samagriAddItems,
  'PanchangScreen': R.panchang,
  'AllTemplates': R.templates,
  'TemplateEditor': R.templateEditor,
  'KundliProfiles': R.kundliProfiles,
  'KundliInput': R.kundliInput,
  'KundliResults': R.kundliResults,
  // Live streaming is not part of this release; land on the E-Puja tab.
  'BroadcasterScreen': R.epuja,
  'InteractiveSessionScreen': R.bookings,
};
