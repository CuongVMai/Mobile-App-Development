import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'dev_faults.dart';

////// DEV-ONLY panel (debug builds only). Arms one-shot faults + sends //////
////// development-only invalid requests. Never changes deployed rules. //////
class DevPanel extends StatefulWidget {
  const DevPanel({super.key, required this.uid, this.verifiedRoundId});
  final String uid;
  final String? verifiedRoundId;

  @override
  State<DevPanel> createState() => _DevPanelState();
}

class _DevPanelState extends State<DevPanel> {
  final _otherUid = TextEditingController();
  final List<String> _log = [];
  bool _running = false;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  void dispose() {
    _otherUid.dispose();
    super.dispose();
  }

  Map<String, Object> _valid(int count) => {
    'schemaVersion': 1,
    'variant': 'B',
    'categoryId': 17,
    'questionCount': 5,
    'correctCount': count,
    'submittedAt': FieldValue.serverTimestamp(),
  };

  ////// expect Firestore rules to reject the operation //////
  Future<void> _expectDenied(String label, Future<void> Function() op) async {
    if (_running) return;
    setState(() => _running = true);
    String result;
    try {
      await op().timeout(const Duration(seconds: 10));
      result = '$label → UNEXPECTED: allowed';
    } on FirebaseException catch (e) {
      result = e.code == 'permission-denied'
          ? '$label → rejected (permission-denied)'
          : '$label → failed with ${e.code}';
    } on TimeoutException {
      result = '$label → no answer in 10s';
    } catch (e) {
      result = '$label → error: $e';
    }
    if (!mounted) return;
    setState(() {
      _log.insert(0, '[${TimeOfDay.now().format(context)}] $result');
      _running = false;
    });
  }

  CollectionReference<Map<String, dynamic>> _attemptsOf(String uid) =>
      _db.collection('users').doc(uid).collection('attempts');

  @override
  Widget build(BuildContext context) {
    final roundId = widget.verifiedRoundId;
    final other = _otherUid.text.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.deepOrange,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'DEV FAULT INJECTION (debug build only, one-shot)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Next OpenTDB response (T03)'),
            Wrap(
              spacing: 6,
              children: [
                for (final f in TriviaFault.values)
                  ChoiceChip(
                    label: Text(f.name),
                    selected: DevFaults.trivia == f,
                    onSelected: (_) => setState(() => DevFaults.trivia = f),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Next commit (T12)'),
            Wrap(
              spacing: 6,
              children: [
                for (final f in CommitFault.values)
                  ChoiceChip(
                    label: Text(f.name),
                    selected: DevFaults.commit == f,
                    onSelected: (_) => setState(() => DevFaults.commit = f),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Next verification read (T09)'),
            Wrap(
              spacing: 6,
              children: [
                for (final f in VerifyFault.values)
                  ChoiceChip(
                    label: Text(f.name),
                    selected: DevFaults.verify == f,
                    onSelected: (_) => setState(() => DevFaults.verify = f),
                  ),
              ],
            ),
            const Divider(height: 28),
            const Text('Rule tests on MY path (T11)'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: _running
                      ? null
                      : () => _expectDenied(
                          'Create with score 6',
                          () => _attemptsOf(widget.uid).doc().set(_valid(6)),
                        ),
                  child: const Text('Score 6'),
                ),
                OutlinedButton(
                  onPressed: _running
                      ? null
                      : () => _expectDenied(
                          'Create with extra field',
                          () =>
                              _attemptsOf(widget.uid)
                                  .doc()
                                  .set({..._valid(3), 'note': 'dev test'}),
                        ),
                  child: const Text('Extra field'),
                ),
                OutlinedButton(
                  onPressed: (_running || roundId == null)
                      ? null
                      : () => _expectDenied(
                          'Update verified round',
                          () =>
                              _attemptsOf(widget.uid)
                                  .doc(roundId)
                                  .update({'correctCount': 0}),
                        ),
                  child: Text(
                    roundId == null
                        ? 'Update (verify a round first)'
                        : 'Update verified round',
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            const Text("Rule tests on ANOTHER user's path (T10)"),
            TextField(
              controller: _otherUid,
              decoration: const InputDecoration(
                labelText: "Other user's UID (from Firebase console)",
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                OutlinedButton(
                  onPressed: (_running || other.isEmpty)
                      ? null
                      : () => _expectDenied(
                          "Read other user's attempts",
                          () =>
                              _attemptsOf(other)
                                  .get(const GetOptions(source: Source.server)),
                        ),
                  child: const Text('Read'),
                ),
                OutlinedButton(
                  onPressed: (_running || other.isEmpty)
                      ? null
                      : () => _expectDenied(
                          "Write other user's path",
                          () => _attemptsOf(other).doc().set(_valid(2)),
                        ),
                  child: const Text('Write'),
                ),
              ],
            ),
            const Divider(height: 28),
            const Text('Results'),
            if (_running) const LinearProgressIndicator(),
            for (final line in _log)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(line, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
