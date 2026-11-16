/// Build-time configuration (`--dart-define` / `--dart-define-from-file`),
/// with the production defaults the React Native app shipped with.
///
/// Example: `flutter run --dart-define-from-file=env/prod.json`
class Env {
  Env._();

  /// Backend API (http client baseURL).
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://mapi.bookmypoojaonline.com');

  /// Share links / web views (live, interactive, list, register-devotee).
  static const webBaseUrl = String.fromEnvironment('WEB_BASE_URL', defaultValue: 'https://mapi.bookmypoojaonline.com');

  static const appDownloadUrl = String.fromEnvironment(
    'APP_DOWNLOAD_URL',
    defaultValue: 'https://play.google.com/store/apps/details?id=com.bookmypoojapandit&hl=en_IN',
  );

  /// Razorpay publishable key id (safe to ship in the client).
  static const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: 'rzp_live_PTzuyIIu6KPSm6');

  /// Google Places key used for the city / address autocomplete fields.
  static const googlePlacesKey = String.fromEnvironment('GOOGLE_PLACES_KEY', defaultValue: 'AIzaSyBUryEXFonbk-8xXlT4KQtj_vX6R-gljEQ');

  /// Support line shown on the approval and help screens.
  static const supportPhone = '8150878717';
}
