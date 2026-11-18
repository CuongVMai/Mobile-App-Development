import 'package:flutter/material.dart';

import 'attempt_repository.dart';

////// restart retrieval (T07): read this user's attempts straight from the server //////
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.uid});
  final String uid;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final AttemptRepository _repo = AttemptRepository(widget.uid);
  bool _loading = false;
  String? _error;
  List<VerifiedAttempt> _attempts = [];
  final Map<String, String> _recheck = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.recentFromServer();
      if (!mounted) return;
      setState(() => _attempts = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeCloudError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ////// re-fetch ONE document by its round ID with a server-only get //////
  Future<void> _verifyOne(String roundId) async {
    setState(() => _recheck[roundId] = 'Checking server...');
    try {
      final v = await _repo.verify(roundId);
      if (!mounted) return;
      setState(
        () => _recheck[roundId] =
            'Cloud verified by ID: ${v.correctCount}/5 at ${v.submittedAt.toLocal()}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _recheck[roundId] = describeCloudError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My cloud attempts'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _attempts.isEmpty
          ? const Center(child: Text('No attempts on the server yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Loaded with a server-only query (not the local cache).',
                  style: TextStyle(fontSize: 12),
                ),
                for (final a in _attempts)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified, color: Colors.green),
                      title: Text(
                        'Round …${a.roundId.substring(a.roundId.length - 4)}'
                        ' · ${a.correctCount}/5',
                      ),
                      subtitle: Text(
                        _recheck[a.roundId] ??
                            'submittedAt ${a.submittedAt.toLocal()}',
                      ),
                      trailing: TextButton(
                        onPressed: () => _verifyOne(a.roundId),
                        child: const Text('Verify'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
