// TODO: Replace with actual Firebase configuration
// Run: flutterfire configure
// This is a placeholder file. You must configure Firebase for your project.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // TODO: Replace with your actual Firebase Web config
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-focuscash',
    storageBucket: 'demo-focuscash.appspot.com',
    authDomain: 'demo-focuscash.firebaseapp.com',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBXRbz27Q4j4AZ5H_yx8kQU5CniuVGCfcs',
    appId: '1:325235851935:web:6bc0b71c40b1bdd30f18aa',
    messagingSenderId: '325235851935',
    projectId: 'focuscash-2676f',
    authDomain: 'focuscash-2676f.firebaseapp.com',
    storageBucket: 'focuscash-2676f.firebasestorage.app',
    measurementId: 'G-PWZQGSYVZP',
  );

  // TODO: Replace with your actual Firebase Windows config

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCm0N6AwYr0FzL_RX9TFPfjE6mktVMa6y0',
    appId: '1:325235851935:android:3eee9f9897f96a570f18aa',
    messagingSenderId: '325235851935',
    projectId: 'focuscash-2676f',
    storageBucket: 'focuscash-2676f.firebasestorage.app',
  );

  // TODO: Replace with your actual Firebase Android config

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAv3ClUN2xipOVt8eARNhXYHou7zuuiMFY',
    appId: '1:325235851935:ios:f17affb78a5ac47c0f18aa',
    messagingSenderId: '325235851935',
    projectId: 'focuscash-2676f',
    storageBucket: 'focuscash-2676f.firebasestorage.app',
    iosBundleId: 'com.focuscash.focusCash',
  );

  // TODO: Replace with your actual Firebase iOS config
}