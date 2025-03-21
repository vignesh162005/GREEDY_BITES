import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import './firebase_service.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static const String _collection = 'users';

  static Future<void> initializeUserCollection() async {
    try {
      final collectionExists = await FirebaseService.verifyCollection(_collection);
      if (!collectionExists) {
        await FirebaseService.initialize();
      }
    } catch (e) {
      print('Error initializing user collection: $e');
      rethrow;
    }
  }

  static Future<DocumentSnapshot> getUserData(String uid) async {
    try {
      await initializeUserCollection();
      final doc = await _firestore.collection(_collection).doc(uid).get();
      print('Retrieved user data for: $uid');
      return doc;
    } catch (e) {
      print('Error getting user data: $e');
      rethrow;
    }
  }

  static Future<bool> isUsernameAvailable(String username) async {
    try {
      await initializeUserCollection();
      final QuerySnapshot result = await _firestore
          .collection(_collection)
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      return result.docs.isEmpty;
    } catch (e) {
      print('Error checking username availability: $e');
      rethrow;
    }
  }

  static Future<void> createUser(UserModel user) async {
    try {
      await initializeUserCollection();
      final userData = user.toMap();
      userData['metadata'] = {
        'lastPasswordChange': FieldValue.serverTimestamp(),
        'createdBy': 'app',
        'accountType': 'email',
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection(_collection).doc(user.id).set(userData);
      print('User created successfully: ${user.email}');
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await initializeUserCollection();
      final updateData = Map<String, dynamic>.from(data);
      updateData['metadata'] = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      await _firestore.collection(_collection).doc(uid).update(updateData);
      print('User updated successfully: $uid');
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  static Future<void> deleteUser(String uid) async {
    try {
      await initializeUserCollection();
      await _firestore.collection(_collection).doc(uid).delete();
      print('User deleted successfully: $uid');
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  static Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String username,
    String? phoneNumber,
  }) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user in Firestore
      final user = UserModel(
        id: userCredential.user!.uid,
        email: email,
        name: name,
        username: username,
        phoneNumber: phoneNumber,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      await createUser(user);
      return userCredential;
    } catch (e) {
      print('Error signing up user: $e');
      rethrow;
    }
  }

  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user document exists
      final userDoc = await getUserData(userCredential.user!.uid);
      
      if (!userDoc.exists) {
        // Create new user document if it doesn't exist
        final newUser = UserModel(
          id: userCredential.user!.uid,
          email: userCredential.user!.email!,
          name: userCredential.user!.displayName ?? email.split('@')[0],
          username: email.split('@')[0],
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        
        await createUser(newUser);
      } else {
        // Update last login time
        await updateUser(userCredential.user!.uid, {
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } catch (e) {
      print('Error signing in user: $e');
      rethrow;
    }
  }

  static Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }

      try {
        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credential
        final userCredential = await _auth.signInWithCredential(credential);

        // Check if user document exists
        final userDoc = await getUserData(userCredential.user!.uid);
        
        if (!userDoc.exists) {
          // Create new user document if it doesn't exist
          final newUser = UserModel(
            id: userCredential.user!.uid,
            email: userCredential.user!.email!,
            name: userCredential.user!.displayName ?? userCredential.user!.email!.split('@')[0],
            username: userCredential.user!.email!.split('@')[0],
            phoneNumber: userCredential.user!.phoneNumber,
            profileImageUrl: userCredential.user!.photoURL,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
            isEmailVerified: userCredential.user!.emailVerified,
            metadata: {
              'lastPasswordChange': DateTime.now().toIso8601String(),
              'createdBy': 'google',
              'accountType': 'google',
              'role': 'user',
            },
          );
          
          await createUser(newUser);
        } else {
          // Update last login time and photo URL if changed
          final updates = {
            'lastLoginAt': FieldValue.serverTimestamp(),
            if (userCredential.user!.photoURL != null)
              'profileImageUrl': userCredential.user!.photoURL,
          };
          await updateUser(userCredential.user!.uid, updates);
        }

        return userCredential;
      } catch (e) {
        print('Error during Google authentication: $e');
        await _googleSignIn.signOut(); // Clean up on error
        rethrow;
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut(); // Sign out from Google as well
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
} 