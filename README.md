# BookMyPooja Partner (Flutter)

Flutter rewrite of the React Native Pandit app (`../bookmypooja-mobileapp-phase-two`),
styled after the BookMyPooja customer app (`bmp_app`). Same package
(`com.bookmypoojapandit`), iOS bundle id (`com.BookMyPoojaPandit`), backend and
Firebase project, so it ships as an update to the live app.

## Run

```
flutter pub get
flutter run                 # debug on a connected device
flutter test
```

Config defaults live in `lib/core/config/env.dart`; override with
`--dart-define=API_BASE_URL=...` (also `WEB_BASE_URL`, `RAZORPAY_KEY_ID`, `GOOGLE_PLACES_KEY`).

## Release (Android)

1. Put the existing upload keystore at `android/keystore/bookmypooja-release-key.keystore`.
2. Copy `android/key.properties.example` → `android/key.properties` and fill in the passwords.
   Without this file release builds are signed with the debug key and must not be uploaded.
3. Bump `version:` in `pubspec.yaml` (build number must stay > 27, the live Play versionCode).
4. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.

## Layout

- `lib/core` — API (`api/api.dart` = every RN endpoint), storage (incl. one-time import of the RN
  AsyncStorage session so users stay logged in), i18n (same JSON files), theme, shared widgets, push.
- `lib/features` — auth, home/panchang, bookings, epuja, devotees, profile, samagri, templates, kundli.
- `assets/brand` — Pandit logo (SVG sources + generated PNGs for icon/splash).

Live streaming (LiveKit broadcaster / interactive session) is intentionally out of this release;
"Join live" shows a coming-soon notice.
