// BLOCK 1: Import Flutter's Material widgets and launch the app.
import 'package:flutter/material.dart';

void main() => runApp(const CounterApp());

// BLOCK 2: This app shell does not change, so it is a StatelessWidget.
class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CounterPage(),
    );
  }
}

// BLOCK 3: This screen changes after user interactions, so it is stateful.
class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  // BLOCK 4: State fields determine what the user sees at any moment.
  int _counter = 0;
  int _increment = 1;
  final List<int> _history = [];
  final TextEditingController _incrementController = TextEditingController(
    text: '1',
  );

  @override
  void dispose() {
    // Controllers use resources; dispose them when this screen is removed.
    _incrementController.dispose();
    super.dispose();
  }

  // BLOCK 5: Helper methods enforce rules before they change UI state.
  bool _isValidValue(int value) => value >= 0 && value <= 100;

  // Activity 05 color-feedback rule, driven by the same counter state.
  Color _counterColor() {
    if (_counter == 0) return Colors.red;
    if (_counter > 50) return Colors.green;
    return Colors.black;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _moveTo(int nextValue) {
    // Reject the action before changing state or creating a history record.
    if (!_isValidValue(nextValue)) {
      _showMessage('Counter must stay between 0 and 100.');
      return;
    }

    setState(() {
      _history.add(_counter); // Save only the state that can be restored.
      _counter = nextValue;
    });
  }

  void _readIncrement(String input) {
    final value = int.tryParse(input);
    // TODO: Improve this message so it explains the accepted input clearly.
    if (value == null || value <= 0) {
      _showMessage(
        'Enter a positive whole number. Your last increment was saved. Do not go above 100 or go below 0.',
      );
      return; // Keep the last valid increment unchanged.
    }
    setState(() => _increment = value);
  }

  void _undo() {
    if (_history.isEmpty) {
      _showMessage('There is no earlier value to restore.');
      return;
    }
    setState(() => _counter = _history.removeLast());
  }

  void _reset() {
    if (_counter != 0) _moveTo(0);
  }

  @override
  Widget build(BuildContext context) {
    // BLOCK 6: Build reads state and connects widgets to user actions.
    return Scaffold(
      appBar: AppBar(title: const Text('Activity 05 Counter')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$_counter',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge
                  ?.copyWith(color: _counterColor()),
            ),
            Slider(
              value: _counter.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '$_counter',
              // TODO: Decide and explain why slider moves should enter history.
              //The slider should enter history because moving it changes the counter just like pressing increase or decrease. When saving the previous value, it lets undo reverse all the numbers that the slider move to so Undo can consistently work no matter how the counter was changed.
              onChanged: (value) => _moveTo(value.round()),
            ),
            TextField(
              controller: _incrementController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Increment amount'),
              onChanged: _readIncrement,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _moveTo(_counter - _increment),
                  child: const Text('Decrease'),
                ),
                ElevatedButton(
                  onPressed: () => _moveTo(_counter + _increment),
                  child: const Text('Increase'),
                ),
                OutlinedButton(onPressed: _reset, child: const Text('Reset')),
                OutlinedButton(onPressed: _undo, child: const Text('Undo')),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _history.isEmpty
                  ? 'History: none'
                  : 'History: ${_history.join(', ')}',
            ),
          ],
        ),
      ),
    );
  }
}
