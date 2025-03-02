import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  static bool get isAuthenticated => currentUser != null;

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}

class AuthGuard extends StatelessWidget {
  final Widget child;
  final String redirectRoute;

  const AuthGuard({
    super.key,
    required this.child,
    this.redirectRoute = '/',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed(redirectRoute);
          });
          return const SizedBox.shrink();
        }

        return child;
      },
    );
  }
} 