import 'package:cloud_firestore/cloud_firestore.dart';

import 'dev_faults.dart';

////// the frozen Class B payload (exactly 6 fields incl. submittedAt) //////
class AttemptPayload {
  const AttemptPayload(this.correctCount);
  final int correctCount;

  Map<String, Object> toCreateData() => {
    'schemaVersion': 1,
    'variant': 'B',
    'categoryId': 17,
    'questionCount': 5,
    'correctCount': correctCount,
    'submittedAt': FieldValue.serverTimestamp(),
  };

  ////// compare the five non-timestamp fields //////
  bool matches(Map<String, dynamic> d) =>
      d['schemaVersion'] == 1 &&
      d['variant'] == 'B' &&
      d['categoryId'] == 17 &&
      d['questionCount'] == 5 &&
      d['correctCount'] == correctCount;
}

enum CommitResult { created, reusedExisting, collision }

class VerificationException implements Exception {
  const VerificationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class VerifiedAttempt {
  const VerifiedAttempt({
    required this.roundId,
    required this.correctCount,
    required this.submittedAt,
  });
  final String roundId;
  final int correctCount;
  final DateTime submittedAt;
}

const _schemaKeys = {
  'schemaVersion',
  'variant',
  'categoryId',
  'questionCount',
  'correctCount',
  'submittedAt',
};

////// a document only counts as "Cloud verified" if it passes ALL of this //////
VerifiedAttempt checkServerSnapshot(
  DocumentSnapshot<Map<String, dynamic>> snap, {
  AttemptPayload? expected,
}) {
  if (!snap.exists) {
    throw const VerificationException(
      'The server has no document for this round ID.',
    );
  }
  if (snap.metadata.isFromCache) {
    throw const VerificationException(
      'Result came from the local cache, not the server.',
    );
  }
  if (snap.metadata.hasPendingWrites) {
    throw const VerificationException('The document still has pending writes.');
  }
  final d = snap.data()!;
  if (d.length != 6 || !d.keys.every(_schemaKeys.contains)) {
    throw const VerificationException('Server document has unexpected fields.');
  }
  final ts = d['submittedAt'];
  if (ts is! Timestamp) {
    throw const VerificationException('Server timestamp is not resolved.');
  }
  final count = d['correctCount'];
  if (d['schemaVersion'] != 1 ||
      d['variant'] != 'B' ||
      d['categoryId'] != 17 ||
      d['questionCount'] != 5 ||
      count is! int ||
      count < 0 ||
      count > 5) {
    throw const VerificationException(
      'Server document does not match the Class B schema.',
    );
  }
  if (expected != null && count != expected.correctCount) {
    throw const VerificationException(
      "Server score differs from this round's score.",
    );
  }
  return VerifiedAttempt(
    roundId: snap.id,
    correctCount: count,
    submittedAt: ts.toDate(),
  );
}

////// distinct, readable cloud errors (labels injected faults) //////
String describeCloudError(Object error) {
  if (error is FirebaseException) {
    final injected = (error.message ?? '').contains(devInjectedTag);
    final base = switch (error.code) {
      'unavailable' =>
        'Cloud service unavailable (offline or server unreachable).',
      'resource-exhausted' =>
        'Cloud quota/resources exhausted. Try again later.',
      'unauthenticated' => 'Not authenticated with the cloud. Sign in again.',
      'permission-denied' => 'Permission denied by Firestore rules.',
      'deadline-exceeded' => 'The cloud request took too long.',
      'aborted' => 'The transaction was aborted. Try again.',
      _ => 'Cloud error (${error.code}).',
    };
    return injected ? '[DEV-INJECTED] $base' : base;
  }
  if (error is VerificationException) return error.message;
  return 'Unexpected error.';
}

class AttemptRepository {
  AttemptRepository(this.uid);

  ////// uid always comes from FirebaseAuth, never from typed input //////
  final String uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get attempts =>
      _db.collection('users').doc(uid).collection('attempts');

  DocumentReference<Map<String, dynamic>> refFor(String roundId) =>
      attempts.doc(roundId);

  ////// generates an ID locally; does NOT create a server record //////
  String newRoundId() => attempts.doc().id;

  ////// create-once transaction on the exact document //////
  Future<CommitResult> commit(String roundId, AttemptPayload payload) async {
    final injected = DevFaults.takeCommit();
    if (injected != CommitFault.none) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: injected == CommitFault.unavailable
            ? 'unavailable'
            : 'resource-exhausted',
        message: '$devInjectedTag commit fault (no request sent)',
      );
    }
    final ref = refFor(roundId);
    final data = payload
        .toCreateData(); ////// frozen BEFORE the transaction //////
    ////// callback may be retried: only read + set here, no UI/IDs/side effects //////
    return _db.runTransaction<CommitResult>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, data);
        return CommitResult.created;
      }
      final existing = snap.data();
      if (existing != null && payload.matches(existing)) {
        return CommitResult
            .reusedExisting; ////// same payload: reuse, no duplicate //////
      }
      return CommitResult
          .collision; ////// different payload: never overwrite //////
    });
  }

  ////// server-only read of the SAME reference //////
  Future<VerifiedAttempt> verify(
    String roundId, {
    AttemptPayload? expected,
  }) async {
    final injected = DevFaults.takeVerify();
    if (injected != VerifyFault.none) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: injected == VerifyFault.permissionDenied
            ? 'permission-denied'
            : 'unavailable',
        message: '$devInjectedTag verification fault (no request sent)',
      );
    }
    final snap = await refFor(roundId)
        .get(const GetOptions(source: Source.server));
    return checkServerSnapshot(snap, expected: expected);
  }

  ////// raw server lookup for reconciling an unknown save //////
  Future<DocumentSnapshot<Map<String, dynamic>>> serverLookup(String roundId) {
    return refFor(roundId).get(const GetOptions(source: Source.server));
  }

  ////// this user's attempts, straight from the server (restart retrieval) //////
  Future<List<VerifiedAttempt>> recentFromServer() async {
    final query = await attempts
        .orderBy('submittedAt', descending: true)
        .limit(10)
        .get(const GetOptions(source: Source.server));
    return query.docs.map((d) => checkServerSnapshot(d)).toList();
  }
}
