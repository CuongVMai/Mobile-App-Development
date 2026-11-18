import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'quiz_screen.dart';
import 'sign_in_screen.dart';

Future<void> main() async {
  ////// binding first, then Firebase, THEN the UI //////
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ScienceSignalApp());
}

class ScienceSignalApp extends StatelessWidget {
  const ScienceSignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Science Signal B',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

////// signedOut -> SignInScreen, signed in -> QuizScreen for THAT uid //////
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  ////// one stable stream, not a new one every build //////
  static final Stream<User?> _authChanges = FirebaseAuth.instance
      .authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const SignInScreen();
        ////// key = uid, so a different user always gets a brand-new quiz state //////
        return QuizScreen(
          key: ValueKey(user.uid),
          uid: user.uid,
          email: user.email ?? '(no email)',
        );
      },
    );
  }
}
