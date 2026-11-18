import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dev_faults.dart';

class ScienceQuestion {
  const ScienceQuestion({required this.text, required this.correctAnswer});
  final String text;
  final String correctAnswer; ////// decoded: exactly "True" or "False" //////
}

class TriviaException implements Exception {
  const TriviaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TriviaApi {
  TriviaApi._();

  ////// exact Class B request //////
  static final uri = Uri.https('opentdb.com', '/api.php', {
    'amount': '5',
    'category': '17',
    'difficulty': 'medium',
    'type': 'boolean',
    'encode': 'url3986',
  });

  ////// OpenTDB rate limit: at least 5 seconds between requests //////
  static const minGap = Duration(seconds: 5);
  static DateTime? _lastRequestAt;

  static Duration get waitRemaining {
    final last = _lastRequestAt;
    if (last == null) return Duration.zero;
    final elapsed = DateTime.now().difference(last);
    return elapsed >= minGap ? Duration.zero : minGap - elapsed;
  }

  ////// one user-triggered request (never an automatic retry loop) //////
  static Future<List<ScienceQuestion>> fetchQuestions() async {
    final wait = waitRemaining;
    if (wait > Duration.zero) await Future.delayed(wait);
    _lastRequestAt = DateTime.now();

    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const TriviaException(
        'The question request timed out after 10 seconds.',
      );
    } on http.ClientException {
      throw const TriviaException(
        'Could not reach the trivia service. Check your connection.',
      );
    }

    ////// check 1: HTTP status //////
    if (response.statusCode != 200) {
      throw TriviaException(
        'Trivia service returned HTTP ${response.statusCode}.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const TriviaException('The trivia service sent invalid JSON.');
    }
    if (decoded is! Map) {
      throw const TriviaException('Unexpected trivia response shape.');
    }
    final data = Map<String, dynamic>.from(decoded);
    var results = data['results'];

    ////// DEV-ONLY injected bad responses (T03) //////
    switch (DevFaults.takeTrivia()) {
      case TriviaFault.none:
        break;
      case TriviaFault.nonzeroCode:
        data['response_code'] = 1;
        break;
      case TriviaFault.fourResults:
        if (results is List && results.isNotEmpty) {
          results = results.sublist(0, results.length - 1);
        }
        break;
      case TriviaFault.badEncoding:
        if (results is List && results.isNotEmpty && results.first is Map) {
          final copy = List<dynamic>.from(results);
          final first = Map<String, dynamic>.from(copy.first as Map);
          first['question'] = 'Broken%ZZencoding';
          copy[0] = first;
          results = copy;
        }
        break;
    }

    ////// check 2: the API's own response code //////
    if (data['response_code'] != 0) {
      throw TriviaException(
        'The trivia API returned response code ${data['response_code']} '
        '(needs 0), so there are no playable questions.',
      );
    }
    ////// check 3: exactly five results //////
    if (results is! List || results.length != 5) {
      final count = results is List ? results.length : 0;
      throw TriviaException('Expected exactly 5 questions but got $count.');
    }
    return results.map(_parse).toList();
  }

  ////// percent-decoding (NOT HTML unescaping); malformed = invalid data //////
  static String _decode(Object? value, String field) {
    if (value is! String) {
      throw TriviaException('Question data is missing "$field".');
    }
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      throw TriviaException('"$field" has malformed percent-encoding.');
    }
  }

  static ScienceQuestion _parse(Object? item) {
    if (item is! Map) {
      throw const TriviaException('A question entry is not an object.');
    }
    final category = _decode(item['category'], 'category');
    final difficulty = _decode(item['difficulty'], 'difficulty');
    final type = _decode(item['type'], 'type');
    final text = _decode(item['question'], 'question');
    final correct = _decode(item['correct_answer'], 'correct_answer');
    final incorrectList = item['incorrect_answers'];
    if (incorrectList is! List || incorrectList.length != 1) {
      throw const TriviaException(
        'Each question needs exactly one wrong answer.',
      );
    }
    final incorrect = _decode(incorrectList.first, 'incorrect_answers');

    if (category != 'Science & Nature') {
      throw TriviaException('Wrong category: "$category".');
    }
    if (difficulty != 'medium') {
      throw TriviaException('Wrong difficulty: "$difficulty".');
    }
    if (type != 'boolean') {
      throw TriviaException('Wrong question type: "$type".');
    }
    if (text.trim().isEmpty) {
      throw const TriviaException('A question is empty.');
    }
    final answers = {correct, incorrect};
    if (answers.length != 2 ||
        !answers.contains('True') ||
        !answers.contains('False')) {
      throw const TriviaException('Answers must be exactly True and False.');
    }
    return ScienceQuestion(text: text, correctAnswer: correct);
  }
}
