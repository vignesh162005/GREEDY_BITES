import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('Firebase initialized successfully');

      // Set settings for better performance
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Create database structure if needed
      await _ensureDatabaseStructure();
      
      _initialized = true;
      print('Firebase setup completed successfully');
    } catch (e) {
      print('Error initializing Firebase: $e');
      rethrow;
    }
  }

  static Future<void> _ensureDatabaseStructure() async {
    try {
      // Check if collections exist before creating
      final usersCollection = _firestore.collection('users');
      final restaurantsCollection = _firestore.collection('restaurants');
      final ordersCollection = _firestore.collection('orders');
      final reviewsCollection = _firestore.collection('reviews');

      // Create collections if they don't exist by adding a temporary document
      await _createCollectionIfNotExists(usersCollection);
      await _createCollectionIfNotExists(restaurantsCollection);
      await _createCollectionIfNotExists(ordersCollection);
      await _createCollectionIfNotExists(reviewsCollection);

      print('Database structure verified successfully');
    } catch (e) {
      print('Error ensuring database structure: $e');
      rethrow;
    }
  }

  static Future<void> _createCollectionIfNotExists(CollectionReference collection) async {
    try {
      // Try to get any document from the collection
      final snapshot = await collection.limit(1).get();
      
      // If collection is empty, create a temporary document
      if (snapshot.docs.isEmpty) {
        final tempDoc = await collection.add({
          'temp': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Delete the temporary document
        await tempDoc.delete();
      }
    } catch (e) {
      print('Error creating collection ${collection.path}: $e');
      rethrow;
    }
  }

  static Future<bool> verifyCollection(String collectionPath) async {
    try {
      if (!_initialized) await initialize();
      final snapshot = await _firestore.collection(collectionPath).limit(1).get();
      return true; // If we got here, the collection exists
    } catch (e) {
      print('Error verifying collection $collectionPath: $e');
      return false;
    }
  }

  static Future<void> createUserDocument(User firebaseUser, Map<String, dynamic> additionalData) async {
    try {
      if (!_initialized) await initialize();
      
      final userData = {
        'email': firebaseUser.email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isEmailVerified': firebaseUser.emailVerified,
        ...additionalData,
        'metadata': {
          'lastPasswordChange': FieldValue.serverTimestamp(),
          'createdBy': 'app',
          'accountType': 'email',
          'role': 'user',
        }
      };

      await _firestore.collection('users').doc(firebaseUser.uid).set(userData);
      print('User document created successfully for: ${firebaseUser.email}');
    } catch (e) {
      print('Error creating user document: $e');
      rethrow;
    }
  }

  static Future<DocumentSnapshot?> getUserDocument(String uid) async {
    try {
      if (!_initialized) await initialize();
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? doc : null;
    } catch (e) {
      print('Error getting user document: $e');
      return null;
    }
  }

  static Future<void> updateUserLoginTime(String uid) async {
    try {
      if (!_initialized) await initialize();
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user login time: $e');
      // Don't rethrow as this is not critical
    }
  }
} 