import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDYs71aFEByjVp1piZUqtlkh12V49_xY9g',
    appId: '1:391985456820:android:9785ba8c788be7e67a99e1',
    messagingSenderId: '391985456820',
    projectId: 'greedy-bites',
    storageBucket: 'greedy-bites.firebasestorage.app',
  );
} 