import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/certificate_trust.dart';
import '../api/truenas_connection.dart';
import '../instances/server_instance.dart';
import 'truenas_session.dart';

/// Why a wait for a server to come back ended without it.
class ServerWaitTimeout implements Exception {
  const ServerWaitTimeout();

  @override
  String toString() => 'ServerWaitTimeout';
}

/// What a wait is waiting for.
enum ServerWait {
  /// Nothing: connect once and report the failure.
  none,

  /// The server was just woken up and is starting.
  wake,

  /// The server was told to restart: it may still answer for a few seconds
  /// before it goes down, and that must not count as it being back.
  restart,
}

/// How often and for how long the app polls a server that is starting.
class ServerWaitTiming {
  const ServerWaitTiming({
    this.interval = const Duration(seconds: 5),
    this.timeout = const Duration(minutes: 10),
    this.downInterval = const Duration(seconds: 2),
    this.downLimit = const Duration(seconds: 90),
  });

  /// Between two tries to connect.
  final Duration interval;

  /// Without an answer by then, the wait gives up. TrueNAS can need several
  /// minutes to boot, and a NAS asleep or off needs the wake-up to work.
  final Duration timeout;

  /// Between two looks at whether a restarting server has gone down.
  final Duration downInterval;

  /// The longest to wait for it to go down.
  final Duration downLimit;
}

final serverWaitTimingProvider = Provider<ServerWaitTiming>(
  (ref) => const ServerWaitTiming(),
);

/// Whether [error] means "not up yet" rather than something waiting cannot
/// fix: a refused login, a certificate or 2FA prompt the user answered no to,
/// or a server that is too old. Everything else (refused or timed-out
/// connections, a web server that answers before the middleware does) is
/// worth another try.
bool isStillStarting(Object error) => switch (error) {
  UnsupportedServerException() ||
  UntrustedCertificateException() ||
  LoginRejected() ||
  ConnectCancelled() => false,
  Exception() => true,
  _ => false,
};

/// Lets a screen stop a wait that is sleeping between two tries, so closing
/// the screen leaves no timer behind.
class WaitToken {
  var _cancelled = false;
  Timer? _timer;
  Completer<void>? _sleeping;

  bool get cancelled => _cancelled;

  /// Completes after [duration], or at once when the wait is cancelled.
  Future<void> sleep(Duration duration) {
    if (_cancelled) return Future.value();
    final sleeping = _sleeping = Completer<void>();
    _timer = Timer(duration, sleeping.complete);
    return sleeping.future;
  }

  void cancel() {
    _cancelled = true;
    _timer?.cancel();
    final sleeping = _sleeping;
    if (sleeping != null && !sleeping.isCompleted) sleeping.complete();
  }
}

/// Runs [attempt] until it succeeds, waiting [interval] between tries, for up
/// to [timeout]. A failure that [retry] rejects is thrown at once; running out
/// of time throws [ServerWaitTimeout]; a cancelled [token] throws
/// [ConnectCancelled].
Future<T> retryUntilOnline<T>(
  Future<T> Function() attempt, {
  required WaitToken token,
  bool Function(Object error) retry = isStillStarting,
  Duration interval = const Duration(seconds: 5),
  Duration timeout = const Duration(minutes: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    if (token.cancelled) throw const ConnectCancelled();
    try {
      return await attempt();
    } catch (error) {
      if (!retry(error)) rethrow;
    }
    if (token.cancelled) throw const ConnectCancelled();
    if (!DateTime.now().add(interval).isBefore(deadline)) {
      throw const ServerWaitTimeout();
    }
    await token.sleep(interval);
  }
}

/// Waits until [isUp] says the server no longer answers, for at most [limit].
/// A server that never goes down in that time (the restart did not happen, or
/// was quick) is not an error: the caller goes on to wait for it to answer.
Future<void> waitUntilDown(
  Future<bool> Function() isUp, {
  required WaitToken token,
  Duration interval = const Duration(seconds: 2),
  Duration limit = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(limit);
  while (!token.cancelled && DateTime.now().isBefore(deadline)) {
    if (!await isUp()) return;
    await token.sleep(interval);
  }
}

/// Whether [instance]'s server answers right now: its web server serves the
/// API versions. A certificate to confirm or a version the app does not
/// support still means somebody is there.
Future<bool> serverAnswers(
  ServerInstance instance, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    final connection = await TrueNasConnection.open(
      instance.address,
      pinnedFingerprint: instance.pinnedFingerprint,
      timeout: timeout,
    );
    await connection.close();
    return true;
  } on UntrustedCertificateException {
    return true;
  } on UnsupportedServerException {
    return true;
  } catch (_) {
    return false;
  }
}
