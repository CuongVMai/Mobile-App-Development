import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';

void main() {
  runApp(const HauntedMansionApp());
}

////// main app /////
class HauntedMansionApp extends StatelessWidget {
  const HauntedMansionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Haunted Creature Registry',
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(),
    );
  }
}
