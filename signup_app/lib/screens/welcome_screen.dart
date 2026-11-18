import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';

import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E1065), Color(0xFF14101F)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('\u{1F987}', style: TextStyle(fontSize: 72)),
              ////// typewriter text /////
              AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'The Haunted Creature Registry',
                    textStyle: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    speed: const Duration(milliseconds: 120),
                  ),
                ],
                totalRepeatCount: 1,
              ),
              const Text(
                'Register your creature companion… if you dare.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ////// push so back works /////
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
                child: const Text('Enter the Registry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
