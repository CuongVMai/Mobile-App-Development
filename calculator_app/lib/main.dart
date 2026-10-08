import 'package:flutter/material.dart';

void main() => runApp(const CalculatorApp());

class CalculatorApp extends StatefulWidget {
  const CalculatorApp({super.key});

  @override
  State<CalculatorApp> createState() => _CalculatorAppState();
}

class _CalculatorAppState extends State<CalculatorApp> {
  bool _isDark = false;
  String _input = '0';
  double? _firstOperand;
  String? _operator;
  bool _hasInput = false;
  bool _replaceInput = true;
  String? _error;

  String _format(double number) {
    final text = number.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  void _enterDigit(String digit) {
    setState(() {
      _input = _replaceInput || _input == '0' ? digit : _input + digit;
      _replaceInput = false;
      _hasInput = true;
      _error = null;
    });
  }

  void _selectOperator(String operation) {
    setState(() {
      // Allow changing the operator while waiting for the second number.
      if (_firstOperand != null && !_hasInput) {
        _operator = operation;
        _error = null;
        return;
      }
      if (!_hasInput) {
        _error = 'Enter your first number, then choose an operation.';
        return;
      }
      if (_firstOperand != null) {
        _error = 'Press = to finish this calculation, or AC to start over.';
        return;
      }
      final value = double.tryParse(_input);
      if (value == null || !value.isFinite) {
        _error =
            'This number is too large. Press AC and enter a smaller number.';
        return;
      }
      _firstOperand = value;
      _operator = operation;
      _hasInput = false;
      _replaceInput = true;
      _error = null;
    });
  }

  void _calculate() {
    setState(() {
      if (_firstOperand == null || _operator == null) {
        _error =
            'Enter a number, choose an operation, then enter another number.';
        return;
      }
      if (!_hasInput) {
        _error = 'Enter your second number, then press =.';
        return;
      }
      final secondOperand = double.tryParse(_input);
      if (secondOperand == null || !secondOperand.isFinite) {
        _error = 'This number is too large. Type a smaller second number.';
        _replaceInput = true;
        _hasInput = false;
        return;
      }
      double result;
      switch (_operator) {
        case '+':
          result = _firstOperand! + secondOperand;
          break;
        case '-':
          result = _firstOperand! - secondOperand;
          break;
        case '×':
          result = _firstOperand! * secondOperand;
          break;
        case '÷':
          if (secondOperand == 0) {
            _error = 'Cannot divide by zero. Type a nonzero second number, then press =.';
            _replaceInput = true;
            _hasInput = false;
            return;
          }
          result = _firstOperand! / secondOperand;
          break;
        default:
          return;
      }
      if (!result.isFinite) {
        _error = 'The result is too large. Press AC and use smaller numbers.';
        return;
      }
      _input = _format(result);
      _firstOperand = null;
      _operator = null;
      _hasInput = true;
      _replaceInput = true;
      _error = null;
    });
  }

  void _allClear(BuildContext context) {
    setState(() {
      _input = '0';
      _firstOperand = null;
      _operator = null;
      _hasInput = false;
      _replaceInput = true;
      _error = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Calculation cleared.'),
          duration: Duration(seconds: 1),
        ),
      );
  }

  void _handleButton(String label, BuildContext context) {
    switch (label) {
      case 'AC':
        _allClear(context);
        break;
      case '=':
        _calculate();
        break;
      case '+':
      case '-':
      case '×':
      case '÷':
        _selectOperator(label);
        break;
      default:
        _enterDigit(label);
    }
  }

  Widget _buttonRow(List<String> labels, BuildContext context) {
    return Expanded(
      child: Row(
        children: labels
            .map(
              (label) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: CalculatorButton(
                    label: label,
                    onPressed: () => _handleButton(label, context),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calculator',
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // This context is below MaterialApp, so it sees the active theme.
      home: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Calculator'),
              actions: [
                IconButton(
                  tooltip: _isDark
                      ? 'Switch to light theme'
                      : 'Switch to dark theme',
                  icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => setState(() => _isDark = !_isDark),
                ),
              ],
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Short screens can scroll rather than squeezing the buttons.
                  final height = constraints.maxHeight < 480
                      ? 480.0
                      : constraints.maxHeight;
                  return SingleChildScrollView(
                    child: Center(
                      child: SizedBox(
                        width: constraints.maxWidth > 480
                            ? 480
                            : constraints.maxWidth,
                        height: height,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _operator == null
                                            ? 'Enter a number'
                                            : '${_format(_firstOperand!)} $_operator',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              _input,
                                              style: TextStyle(
                                                fontSize: 48,
                                                color: colors.onSurface,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 76,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _error ?? 'Choose an operation and press =. AC starts over.',
                                      style: TextStyle(
                                        color: _error == null
                                            ? colors.onSurfaceVariant
                                            : colors.error,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _buttonRow(['7', '8', '9', '÷'], context),
                              _buttonRow(['4', '5', '6', '×'], context),
                              _buttonRow(['1', '2', '3', '-'], context),
                              _buttonRow(['AC', '0', '=', '+'], context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class CalculatorButton extends StatelessWidget {
  const CalculatorButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isOperation = ['+', '-', '×', '÷', '='].contains(label);
    return SizedBox.expand(
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: label == 'AC'
              ? colors.tertiaryContainer
              : isOperation
              ? colors.primary
              : colors.secondaryContainer,
          foregroundColor: label == 'AC'
              ? colors.onTertiaryContainer
              : isOperation
              ? colors.onPrimary
              : colors.onSecondaryContainer,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
