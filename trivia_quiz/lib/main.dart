import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ScienceSignalApp());
}

class ScienceSignalApp extends StatelessWidget {
  const ScienceSignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Science Signal',
      ////// Christmas theme: pine green + christmas red, cream background //////
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20), ////// pine green //////
          primary: const Color(0xFF1B5E20),
          secondary: const Color(0xFFC62828), ////// christmas red //////
          surface: const Color(0xFFFFF8E7), ////// cream //////
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8E7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFC62828),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        cardTheme: const CardThemeData(color: Colors.white),
      ),
      home: const ScienceQuizScreen(),
    );
  }
}

class ScienceQuestion {
  const ScienceQuestion({required this.text, required this.correctAnswer});

  final String text;
  final String correctAnswer;

  factory ScienceQuestion.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['question'] is! String ||
        value['correct_answer'] is! String ||
        value['incorrect_answers'] is! List) {
      throw const FormatException('Invalid question data.');
    }

    final text = Uri.decodeComponent(value['question'] as String);
    final correctAnswer = Uri.decodeComponent(
      value['correct_answer'] as String,
    );
    final incorrectAnswers = value['incorrect_answers'] as List;
    if (text.trim().isEmpty ||
        (correctAnswer != 'True' && correctAnswer != 'False') ||
        incorrectAnswers.length != 1 ||
        incorrectAnswers.first is! String) {
      throw const FormatException('Invalid true-or-false question.');
    }
    final incorrectAnswer = Uri.decodeComponent(
      incorrectAnswers.first as String,
    );
    if ((incorrectAnswer != 'True' && incorrectAnswer != 'False') ||
        incorrectAnswer == correctAnswer) {
      throw const FormatException('Invalid true-or-false answers.');
    }
    return ScienceQuestion(text: text, correctAnswer: correctAnswer);
  }
}

class ScienceQuizScreen extends StatefulWidget {
  const ScienceQuizScreen({super.key});

  @override
  State<ScienceQuizScreen> createState() => _ScienceQuizScreenState();
}

class _ScienceQuizScreenState extends State<ScienceQuizScreen> {
  static final _questionUri = Uri.https('opentdb.com', '/api.php', {
    'amount': '5',
    'category': '17',
    'difficulty': 'medium',
    'type': 'boolean',
    'encode': 'url3986',
  });

  ////// category name used in the score payload //////
  static const _category = 'Science & Nature';

  List<ScienceQuestion> _questions = [];
  bool _loading = true;
  String? _error;

  ////// quiz round state //////
  int _currentIndex = 0; ////// which question is showing (0-4) //////
  List<String?> _answers =
      []; ////// saved choice for each question (null = not answered yet) //////
  int _score = 0;
  bool _finished = false; ////// true after question 5 -> show results //////

  ////// simulated submission state //////
  bool _submitting = false;
  Map<String, Object>? _submittedPayload;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _error = null;
      _questions = [];
      ////// reset the whole round so replay starts fresh //////
      _currentIndex = 0;
      _answers = [];
      _score = 0;
      _finished = false;
      _submitting = false;
      _submittedPayload = null;
    });

    try {
      final response = await http
          .get(_questionUri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw FormatException('Server returned HTTP ${response.statusCode}.');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['response_code'] != 0) {
        throw const FormatException('The trivia API did not return questions.');
      }
      final results = data['results'];
      if (results is! List || results.length != 5) {
        throw const FormatException('Expected five trivia questions.');
      }
      final questions = results.map(ScienceQuestion.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _questions = questions;
        ////// one empty answer slot per question //////
        _answers = List<String?>.filled(questions.length, null);
        _loading = false;
      });
    } on TimeoutException {
      _showError('The request timed out. Please try again.');
    } on http.ClientException catch (error) {
      _showError('The request failed: ${error.message}');
    } on FormatException catch (error) {
      _showError('Could not load questions: ${error.message}');
    } catch (_) {
      ////// safety net so any other failure still shows an error + retry //////
      _showError('Something went wrong loading questions. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  ////// user taps True or False //////
  void _selectAnswer(String choice) {
    ////// one-answer rule: if this question already has an answer, ignore the tap //////
    if (_answers[_currentIndex] != null) return;
    setState(() {
      _answers[_currentIndex] =
          choice; ////// saved for the results review //////
      if (choice == _questions[_currentIndex].correctAnswer) {
        _score++; ////// at most +1 per question //////
      }
    });
  }

  ////// go to the next question (only after answering) //////
  void _continue() {
    if (_answers[_currentIndex] == null) return;
    setState(() {
      if (_currentIndex < _questions.length - 1) {
        _currentIndex++; ////// next question starts with no selection //////
      } else {
        _finished = true;
      }
    });
  }

  ////// SIMULATED score submission (no endpoint was given, so nothing is sent) //////
  Future<void> _submitScore() async {
    ////// block duplicate submissions //////
    if (_submitting || _submittedPayload != null) return;

    final payload = <String, Object>{
      'score': _score,
      'total': _questions.length,
      'category': _category,
    };

    setState(() => _submitting = true);
    await Future.delayed(
      const Duration(seconds: 2),
    ); ////// fake network wait //////
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submittedPayload = payload;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('🎁 Loading science questions...'),
          ],
        ),
      );
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadQuestions, child: const Text('Retry')),
          ],
        ),
      );
    } else if (_finished) {
      body = _buildResults(context);
    } else {
      body = _buildQuestion(context);
    }

    return Scaffold(
      ////// festive title //////
      appBar: AppBar(title: const Text('🎄 Science Signal 🎅')),
      body: Padding(padding: const EdgeInsets.all(24), child: body),
    );
  }

  ////// one question at a time //////
  Widget _buildQuestion(BuildContext context) {
    final question = _questions[_currentIndex];
    final selected = _answers[_currentIndex];
    final answered = selected != null;
    final isCorrect = selected == question.correctAnswer;
    final isLast = _currentIndex == _questions.length - 1;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ////// question number + progress //////
          Text(
            'Question ${_currentIndex + 1} of ${_questions.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
          ),
          const SizedBox(height: 8),
          Text('Score: $_score'),
          const SizedBox(height: 24),
          Text(
            question.text,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          for (final choice in const ['True', 'False'])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _answerButton(choice, question, selected),
            ),
          ////// text feedback (not just color) //////
          if (answered)
            Text(
              isCorrect
                  ? 'Correct! The answer is ${question.correctAnswer}.'
                  : 'Incorrect. You chose $selected, but the answer is ${question.correctAnswer}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          const SizedBox(height: 24),
          ////// continue only works after an answer //////
          FilledButton(
            onPressed: answered ? _continue : null,
            child: Text(isLast ? 'See results' : 'Continue'),
          ),
          if (!answered)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Choose an answer to continue.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  ////// True/False button: green = correct answer, red = wrong pick //////
  Widget _answerButton(
    String choice,
    ScienceQuestion question,
    String? selected,
  ) {
    Color? color;
    String label = choice;
    if (selected != null) {
      if (choice == question.correctAnswer) {
        color = Colors.green;
        label = '$choice  ✓ correct answer';
      } else if (choice == selected) {
        color = Colors.red;
        label = '$choice  ✗ your answer';
      }
    }

    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: color,
        disabledBackgroundColor: color ?? Colors.grey.shade300,
        disabledForegroundColor: color != null ? Colors.white : Colors.black54,
      ),
      ////// disabled after answering = no second tap //////
      onPressed: selected == null ? () => _selectAnswer(choice) : null,
      child: Text(label, style: const TextStyle(fontSize: 18)),
    );
  }

  ////// results: score, review of all 5, submission, replay //////
  Widget _buildResults(BuildContext context) {
    final payload = _submittedPayload;

    return ListView(
      children: [
        Text(
          '🎄 Round complete 🎄',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Your score: $_score / ${_questions.length}',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text('Answer review', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var i = 0; i < _questions.length; i++) _reviewCard(i),
        const SizedBox(height: 24),
        Text(
          'Score submission (simulation)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'No endpoint was provided, so this only simulates a submission. '
          'Nothing is sent to a server.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          ////// disabled while pending or after done = no duplicates //////
          onPressed: (_submitting || payload != null) ? null : _submitScore,
          icon: const Icon(Icons.send),
          label: Text(
            _submitting
                ? 'Simulating submission...'
                : payload != null
                ? 'Simulation complete'
                : 'Submit score (simulation)',
          ),
        ),
        if (_submitting)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (payload != null)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SIMULATED submission complete. No backend request was sent, '
                    'so this score was NOT saved to any server.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Payload that would be sent:'),
                  const SizedBox(height: 4),
                  Text(
                    const JsonEncoder.withIndent('  ').convert(payload),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        ////// replay = reset + fetch a fresh set //////
        OutlinedButton.icon(
          onPressed: _submitting ? null : _loadQuestions,
          icon: const Icon(Icons.replay),
          label: const Text('Play again (new questions)'),
        ),
      ],
    );
  }

  ////// one review entry: question, your answer, correct answer, result //////
  Widget _reviewCard(int i) {
    final question = _questions[i];
    final chosen = _answers[i];
    final correct = chosen == question.correctAnswer;

    return Card(
      child: ListTile(
        leading: Icon(
          correct ? Icons.check_circle : Icons.cancel,
          color: correct ? Colors.green : Colors.red,
        ),
        title: Text('${i + 1}. ${question.text}'),
        subtitle: Text(
          'Your answer: ${chosen ?? '-'}\n'
          'Correct answer: ${question.correctAnswer}\n'
          '${correct ? 'Correct' : 'Incorrect'}',
        ),
        isThreeLine: true,
      ),
    );
  }
}
