import 'package:flutter/material.dart';

void main() {
  runApp(const CounterImageToggleApp());
}

class CounterImageToggleApp extends StatelessWidget {
  const CounterImageToggleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // State variables
  int _counter = 0;
  int _step = 1;
  bool _isDark = false;
  bool _isFirstImage = true;

  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
      value: 1.0,
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _incrementCounter() {
    setState(() {
      _counter += _step;
    });
  }

  void _decrementCounter() {
    setState(() {
      _counter -= _step;

      // Prevents the counter from going below zero
      if (_counter < 0) {
        _counter = 0;
      }
    });
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  void _changeStep(int newStep) {
    setState(() {
      _step = newStep;
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
    });
  }

  void _toggleImage() {
    _controller.forward(from: 0);

    setState(() {
      _isFirstImage = !_isFirstImage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CW1 Counter & Toggle',
      debugShowCheckedModeBanner: false,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('CW1 Counter & Toggle'),
          actions: [
            IconButton(
              onPressed: _toggleTheme,
              icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Counter: $_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: 12),

              Text(
                'Current step: +$_step',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 12),

              // Step selector buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('+1'),
                    selected: _step == 1,
                    onSelected: (_) => _changeStep(1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('+5'),
                    selected: _step == 5,
                    onSelected: (_) => _changeStep(5),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('+10'),
                    selected: _step == 10,
                    onSelected: (_) => _changeStep(10),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Counter controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _counter == 0 ? null : _decrementCounter,
                    child: Text('-$_step'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _incrementCounter,
                    child: Text('+$_step'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _counter == 0 ? null : _resetCounter,
                    child: const Text('Reset'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              FadeTransition(
                opacity: _fade,
                child: Image.asset(
                  _isFirstImage ? 'assets/image1.png' : 'assets/image2.png',
                  width: 180,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _toggleImage,
                child: const Text('Toggle Image'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
