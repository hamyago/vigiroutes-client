import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web non supporté');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Plateforme non supportée');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyDAxzvDBgb8tGMFmYcurMhGZZ_qourHmoc',
    appId:             '1:603913934385:android:9b1b5c2778c7e114836710',
    messagingSenderId: '603913934385',
    projectId:         'vigiroutes',
    storageBucket:     'vigiroutes.firebasestorage.app',
  );
}
