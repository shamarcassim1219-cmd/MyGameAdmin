import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('This platform is not supported.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDldtjCAzG1OibYw9t2aaG72rGfDi1_G08',
    appId: '1:354593690287:android:354a27d323ffe9dc1a3a5a',
    messagingSenderId: '354593690287',
    projectId: 'mygame-b087a',
    storageBucket: 'mygame-b087a.firebasestorage.app',
  );
}
