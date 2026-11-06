import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'auth_gate.dart';

Future<void> main() async {
  ////// 1. set up Flutter's binding so plugins (Firebase) can talk to Android //////
  WidgetsFlutterBinding.ensureInitialized();

  ////// 2. connect to MY Firebase project before anything else //////
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  ////// 3. only now start the UI //////
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firebase Auth Lab',
      ////// AuthGate decides which screen to show based on sign-in state //////
      home: AuthGate(),
    );
  }
}
