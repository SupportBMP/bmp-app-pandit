import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

/// Firebase project `bookmypooja-cf368` — same apps the React
/// Native build used (values from google-services.json / GoogleService-Info.plist).
class FirebaseConfig {
  FirebaseConfig._();

  static FirebaseOptions get current => Platform.isIOS ? ios : android;

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyBBhn9jJYDxX5QtO3OeF39YLOnPjmv8ADs',
    appId: '1:308360965121:android:02e471be1a476caa96e400',
    messagingSenderId: '308360965121',
    projectId: 'bookmypooja-cf368',
    storageBucket: 'bookmypooja-cf368.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCAOJoaOHlTX7PU8ONHqPkrsVUyfbWWh4w',
    appId: '1:308360965121:ios:717cca27f2fd644b96e400',
    messagingSenderId: '308360965121',
    projectId: 'bookmypooja-cf368',
    storageBucket: 'bookmypooja-cf368.firebasestorage.app',
    iosBundleId: 'com.BookMyPoojaPandit',
  );
}
