import 'package:flutter/foundation.dart';

////// DEV-ONLY fault injection. Debug builds only; every fault fires ONCE then clears. //////
////// Deployed Firestore rules are never changed by any of this. //////

enum TriviaFault { none, badEncoding, nonzeroCode, fourResults }

enum CommitFault { none, unavailable, resourceExhausted }

enum VerifyFault { none, permissionDenied, unavailable }

class DevFaults {
  DevFaults._();

  static TriviaFault trivia = TriviaFault.none;
  static CommitFault commit = CommitFault.none;
  static VerifyFault verify = VerifyFault.none;

  static bool get anyArmed =>
      trivia != TriviaFault.none ||
      commit != CommitFault.none ||
      verify != VerifyFault.none;

  static TriviaFault takeTrivia() {
    if (!kDebugMode) return TriviaFault.none;
    final f = trivia;
    trivia = TriviaFault.none;
    return f;
  }

  static CommitFault takeCommit() {
    if (!kDebugMode) return CommitFault.none;
    final f = commit;
    commit = CommitFault.none;
    return f;
  }

  static VerifyFault takeVerify() {
    if (!kDebugMode) return VerifyFault.none;
    final f = verify;
    verify = VerifyFault.none;
    return f;
  }
}

////// marker so the UI can label injected errors //////
const devInjectedTag = 'DEV-INJECTED';
