import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'authentication_screen.dart';
import 'profile_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      ////// listen to sign-in state; no parentheses: it's a cached stream property //////
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        ////// still checking if a saved session exists (session restoration) //////
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Unable to check sign-in status. Try again.'),
            ),
          );
        }
        ////// signed in -> profile; signed out -> sign-in screen (protected UI) //////
        if (snapshot.hasData) return const ProfileScreen();
        return const AuthenticationScreen();
      },
    );
  }
}
