import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({
    super.key,
    required this.userName,
    required this.creatureType,
  });

  final String userName;
  final String creatureType;

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    _confetti.play(); ////// confetti when it opens /////
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('\u{1F383}', style: TextStyle(fontSize: 72)),
                Text(
                  'Welcome, ${widget.userName}!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ////// took const off, wouldnt compile with it /////
                Text('Creature registered: ${widget.creatureType}.'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text('Back to the Foyer'),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(confettiController: _confetti),
          ),
        ],
      ),
    );
  }
}
