import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'attempt_repository.dart';
import 'dev_panel.dart';
import 'history_screen.dart';
import 'trivia_api.dart';

////// the Class B state machine (signedOut + authError live in AuthGate / SignInScreen) //////
enum QuizPhase {
  loading,
  requestError,
  playing,
  readyToSubmit,
  submitting,
  verifying,
  cloudVerified,
  saveUnknown,
  saveFailed, ////// definite non-commit (unavailable / resource-exhausted / unauthenticated) //////
  permissionDenied, ////// commit rejected by rules //////
  verificationUnavailable, ////// commit acknowledged, server read failed //////
  collision, ////// same round ID already holds a different score //////
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.uid, required this.email});
  final String uid;
  final String email;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final AttemptRepository _repo = AttemptRepository(widget.uid);

  QuizPhase _phase = QuizPhase.loading;
  String? _message;

  List<ScienceQuestion> _questions = [];
  int _index = 0;
  List<String?> _answers = [];

  String?
  _roundId; ////// generated at round start, reused for every retry //////
  AttemptPayload? _frozenPayload; ////// frozen on first submit //////
  String? _commitNote;
  VerifiedAttempt? _verified;
  bool _busy = false; ////// blocks overlapping cloud operations //////

  ////// replay + sign-out are locked while the cloud outcome is unresolved //////
  bool get _unresolved =>
      _busy ||
      _phase == QuizPhase.submitting ||
      _phase == QuizPhase.verifying ||
      _phase == QuizPhase.saveUnknown ||
      _phase == QuizPhase.verificationUnavailable;

  ////// score is derived from saved answers, so a question can never count twice //////
  int get _score {
    var total = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i].correctAnswer) total++;
    }
    return total;
  }

  String get _roundSuffix {
    final id = _roundId;
    if (id == null || id.length < 4) return '—';
    return '…${id.substring(id.length - 4)}';
  }

  ////// callbacks only apply if the SAME user + SAME round are still current //////
  bool _stillCurrent(String uid, [String? roundId]) =>
      mounted &&
      FirebaseAuth.instance.currentUser?.uid == uid &&
      (roundId == null || roundId == _roundId);

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  Future<void> _startRound() async {
    if (_unresolved) return;
    final uid = widget.uid;
    final wait = TriviaApi.waitRemaining;
    setState(() {
      _phase = QuizPhase.loading;
      _message = wait > Duration.zero
          ? 'Waiting ${wait.inSeconds + 1}s to respect the OpenTDB rate limit...'
          : null;
      _questions = [];
      _answers = [];
      _index = 0;
      _roundId = null;
      _frozenPayload = null;
      _commitNote = null;
      _verified = null;
    });
    try {
      final questions = await TriviaApi.fetchQuestions();
      if (!_stillCurrent(uid)) return;
      setState(() {
        _questions = questions;
        _answers = List<String?>.filled(questions.length, null);
        _roundId = _repo.newRoundId(); ////// new ID per round //////
        _phase = QuizPhase.playing;
        _message = null;
      });
    } on TriviaException catch (e) {
      if (!_stillCurrent(uid)) return;
      setState(() {
        _phase = QuizPhase.requestError;
        _message = e.message;
      });
    } catch (_) {
      if (!_stillCurrent(uid)) return;
      setState(() {
        _phase = QuizPhase.requestError;
        _message = 'Something went wrong loading questions.';
      });
    }
  }

  void _select(String choice) {
    if (_phase != QuizPhase.playing) return;
    if (_answers[_index] != null) return; ////// one answer per question //////
    setState(() => _answers[_index] = choice);
  }

  void _continue() {
    if (_answers[_index] == null) return; ////// must answer first //////
    setState(() {
      if (_index < _questions.length - 1) {
        _index++;
      } else {
        _phase =
            QuizPhase.readyToSubmit; ////// all five answers are final //////
      }
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_phase != QuizPhase.readyToSubmit && _phase != QuizPhase.saveFailed) {
      return;
    }
    final uid = widget.uid;
    final roundId = _roundId!;
    final payload = _frozenPayload ??= AttemptPayload(_score);

    _busy = true;
    setState(() {
      _phase = QuizPhase.submitting;
      _message = null;
    });
    try {
      ////// 10s UI timeout (does NOT cancel the real Firestore operation) //////
      final result = await _repo
          .commit(roundId, payload)
          .timeout(const Duration(seconds: 10));
      if (!_stillCurrent(uid, roundId)) return;
      if (result == CommitResult.collision) {
        setState(() {
          _phase = QuizPhase.collision;
          _message =
              'Round $_roundSuffix already exists with a different '
              'score. Nothing was overwritten.';
        });
        return;
      }
      _commitNote = result == CommitResult.created
          ? 'Write acknowledged (new document created).'
          : 'Write acknowledged (identical document already existed; reused, no duplicate).';
      await _verify(uid, roundId, payload);
    } on TimeoutException {
      if (!_stillCurrent(uid, roundId)) return;
      setState(() {
        _phase = QuizPhase.saveUnknown;
        _message =
            'No acknowledgement within 10 seconds. The write may still '
            'finish in the background. Check the cloud before retrying.';
      });
    } on FirebaseException catch (e) {
      if (!_stillCurrent(uid, roundId)) return;
      setState(() {
        _phase = e.code == 'permission-denied'
            ? QuizPhase.permissionDenied
            : QuizPhase.saveFailed;
        _message = describeCloudError(e);
      });
    } catch (e) {
      if (!_stillCurrent(uid, roundId)) return;
      setState(() {
        _phase = QuizPhase.saveUnknown;
        _message =
            'Unexpected error during save. Check the cloud before retrying.';
      });
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  ////// server-only verification of the SAME round ID (never writes) //////
  Future<void> _verify(
    String uid,
    String roundId,
    AttemptPayload payload,
  ) async {
    setState(() {
      _phase = QuizPhase.verifying;
      _message = null;
    });
    try {
      final verified = await _repo
          .verify(roundId, expected: payload)
          .timeout(const Duration(seconds: 10));
      if (!_stillCurrent(uid, roundId)) return;
      setState(() {
        _verified = verified;
        _phase = QuizPhase.cloudVerified;
        _message = null;
      });
    } on TimeoutException {
      if (!_stillCurrent(uid, roundId)) return;
      setState(() {
        _phase = QuizPhase.verificationUnavailable;
        _message = 'Verification read timed out.';
      });
    } catch (e) {
      if (!_stillCurrent(uid, roundId)) return;
      setState(() {
        _phase = QuizPhase.verificationUnavailable;
        _message = describeCloudError(e);
      });
    }
  }

  Future<void> _retryVerification() async {
    if (_busy || _phase != QuizPhase.verificationUnavailable) return;
    final uid = widget.uid;
    final roundId = _roundId!;
    _busy = true;
    try {
      await _verify(uid, roundId, _frozenPayload!);
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  ////// saveUnknown: ask the SERVER about the original ID before any retry //////
  Future<void> _reconcile() async {
    if (_busy || _phase != QuizPhase.saveUnknown) return;
    final uid = widget.uid;
    final roundId = _roundId!;
    final payload = _frozenPayload!;
    _busy = true;
    setState(() => _message = 'Checking the server for round $_roundSuffix...');
    try {
      final snap = await _repo
          .serverLookup(roundId)
          .timeout(const Duration(seconds: 10));
      if (!_stillCurrent(uid, roundId)) return;
      if (!snap.exists) {
        setState(() {
          _phase = QuizPhase.saveFailed;
          _message =
              'The server has no record of round $_roundSuffix, so it '
              'was not saved. You can submit again with the SAME round ID.';
        });
        return;
      }
      final existing = snap.data();
      if (existing != null && !payload.matches(existing)) {
        setState(() {
          _phase = QuizPhase.collision;
          _message =
              'Round $_roundSuffix exists with a different score. '
              'Nothing was overwritten.';
        });
        return;
      }
      final verified = checkServerSnapshot(snap, expected: payload);
      setState(() {
        _commitNote = 'Write found on the server during reconciliation.';
        _verified = verified;
        _phase = QuizPhase.cloudVerified;
        _message = null;
      });
    } on TimeoutException {
      if (!_stillCurrent(uid, roundId)) return;
      setState(
        () => _message =
            'Still could not reach the server. Status remains unknown.',
      );
    } catch (e) {
      if (!_stillCurrent(uid, roundId)) return;
      setState(
        () => _message =
            'Still could not confirm: ${describeCloudError(e)} Status remains unknown.',
      );
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _signOut() async {
    if (_unresolved) return;
    await FirebaseAuth.instance.signOut();
  }

  void _openDevPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          DevPanel(uid: widget.uid, verifiedRoundId: _verified?.roundId),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Science Signal B'),
        actions: [
          IconButton(
            tooltip: 'My cloud attempts',
            icon: const Icon(Icons.cloud_queue),
            onPressed: _unresolved
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HistoryScreen(uid: widget.uid),
                    ),
                  ),
          ),
          if (kDebugMode)
            IconButton(
              tooltip: 'DEV fault injection',
              icon: const Icon(Icons.bug_report, color: Colors.deepOrange),
              onPressed: _openDevPanel,
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _unresolved ? null : _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Signed in as ${widget.email} · UID '
              '…${widget.uid.substring(widget.uid.length - 4)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case QuizPhase.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_message ?? 'Loading 5 science questions...'),
            ],
          ),
        );
      case QuizPhase.requestError:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _message ?? 'Could not load questions.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'No round was started. Retry waits at least 5 seconds between requests.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _startRound,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      case QuizPhase.playing:
        return _buildQuestion(context);
      default:
        return _buildResults(context);
    }
  }

  Widget _buildQuestion(BuildContext context) {
    final q = _questions[_index];
    final selected = _answers[_index];
    final answered = selected != null;
    final correct = selected == q.correctAnswer;
    final isLast = _index == _questions.length - 1;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Question ${_index + 1} of ${_questions.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (_index + 1) / _questions.length),
          const SizedBox(height: 8),
          Text('Score: $_score · Round $_roundSuffix'),
          const SizedBox(height: 24),
          Text(
            q.text,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ////// fixed order: True then False //////
          for (final choice in const ['True', 'False'])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _answerButton(choice, q, selected),
            ),
          if (answered)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  correct ? Icons.check_circle : Icons.cancel,
                  color: correct ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    correct
                        ? 'Correct! The answer is ${q.correctAnswer}.'
                        : 'Incorrect. You chose $selected; the answer is ${q.correctAnswer}.',
                    style: TextStyle(
                      color: correct
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
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

  Widget _answerButton(String choice, ScienceQuestion q, String? selected) {
    Color? color;
    if (selected != null) {
      if (choice == q.correctAnswer) {
        color = Colors.green;
      } else if (choice == selected) {
        color = Colors.red;
      }
    }
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: color,
        disabledBackgroundColor: color ?? Colors.grey.shade300,
        disabledForegroundColor: color != null ? Colors.white : Colors.black54,
      ),
      onPressed: selected == null ? () => _select(choice) : null,
      child: Text(choice, style: const TextStyle(fontSize: 18)),
    );
  }

  Widget _buildResults(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Round complete · $_roundSuffix',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        Text(
          'Score: $_score / ${_questions.length}',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text('Answer review', style: Theme.of(context).textTheme.titleMedium),
        for (var i = 0; i < _questions.length; i++) _reviewCard(i),
        const SizedBox(height: 16),
        _cloudStatusCard(context),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _unresolved ? null : _startRound,
          icon: const Icon(Icons.replay),
          label: const Text('Replay (new round ID)'),
        ),
        if (_unresolved)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Replay and sign-out are locked until the cloud result is resolved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _reviewCard(int i) {
    final q = _questions[i];
    final chosen = _answers[i];
    final ok = chosen == q.correctAnswer;
    return Card(
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.green : Colors.red,
        ),
        title: Text('${i + 1}. ${q.text}'),
        subtitle: Text(
          'Your answer: ${chosen ?? '-'}\n'
          'Correct answer: ${q.correctAnswer} · ${ok ? 'Correct' : 'Incorrect'}',
        ),
        isThreeLine: true,
      ),
    );
  }

  ////// each outcome gets its own icon, color, wording, and allowed action //////
  Widget _cloudStatusCard(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final String title;
    Widget? action;
    var spinner = false;

    switch (_phase) {
      case QuizPhase.readyToSubmit:
        icon = Icons.cloud_upload_outlined;
        color = Colors.blueGrey;
        title = 'Not submitted yet';
        action = FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.send),
          label: const Text('Submit to cloud'),
        );
        break;
      case QuizPhase.submitting:
        icon = Icons.cloud_sync;
        color = Colors.blue;
        title = 'Committing to Firestore...';
        spinner = true;
        break;
      case QuizPhase.verifying:
        icon = Icons.manage_search;
        color = Colors.blue;
        title = 'Verifying with a server-only read...';
        spinner = true;
        break;
      case QuizPhase.cloudVerified:
        icon = Icons.verified;
        color = Colors.green;
        title = 'Cloud verified';
        break;
      case QuizPhase.verificationUnavailable:
        icon = Icons.cloud_done_outlined;
        color = Colors.orange.shade800;
        title = 'Write acknowledged; verification unavailable.';
        action = FilledButton.icon(
          onPressed: _busy ? null : _retryVerification,
          icon: const Icon(Icons.manage_search),
          label: const Text('Retry server read (same ID)'),
        );
        break;
      case QuizPhase.saveUnknown:
        icon = Icons.help_outline;
        color = Colors.orange.shade800;
        title = 'Save status unknown';
        action = FilledButton.icon(
          onPressed: _busy ? null : _reconcile,
          icon: const Icon(Icons.cloud_sync),
          label: const Text('Check cloud for this round'),
        );
        break;
      case QuizPhase.saveFailed:
        icon = Icons.cloud_off;
        color = Colors.red;
        title = 'Not saved';
        action = FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.send),
          label: const Text('Submit again (same round ID)'),
        );
        break;
      case QuizPhase.permissionDenied:
        icon = Icons.block;
        color = Colors.red;
        title = 'Write rejected by Firestore rules';
        break;
      case QuizPhase.collision:
        icon = Icons.warning_amber;
        color = Colors.red;
        title = 'Round ID collision: nothing overwritten';
        break;
      default:
        icon = Icons.cloud_outlined;
        color = Colors.grey;
        title = '';
    }

    final verified = _verified;
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            if (spinner)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
            if (_commitNote != null &&
                _phase != QuizPhase.readyToSubmit &&
                _phase != QuizPhase.submitting)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_commitNote!),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_message!),
              ),
            if (verified != null && _phase == QuizPhase.cloudVerified)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Server read: round …${verified.roundId.substring(verified.roundId.length - 4)}'
                  ' · correctCount ${verified.correctCount}/5'
                  ' · submittedAt ${verified.submittedAt.toLocal()}'
                  ' · source: server, no pending writes',
                ),
              ),
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 12), child: action),
          ],
        ),
      ),
    );
  }
}
