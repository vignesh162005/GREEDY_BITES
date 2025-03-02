import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        // Replace these values with your actual Firebase configuration values from google-services.json
        apiKey: 'your_api_key',
        appId: 'your_app_id',
        messagingSenderId: 'your_messaging_sender_id',
        projectId: 'your_project_id',
        storageBucket: 'your_storage_bucket',
      ),
    );
  }
} 