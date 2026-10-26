import '../api/api_exception.dart';
import '../api/auth.dart';
import '../api/certificate_trust.dart';
import '../api/events.dart';
import '../api/explorer_api.dart';
import '../api/json_rpc_client.dart';
import '../api/method_catalog.dart';
import '../api/protection_api.dart';
import '../api/reconnecting_client.dart';
import '../api/reporting_api.dart';
import '../api/sharing_api.dart';
import '../api/shell_session.dart';
import '../api/storage_api.dart';
import '../api/system_api.dart';
import '../api/truenas_connection.dart';
import '../api/workloads_api.dart';
import '../instances/server_instance.dart';
import '../logging/app_log.dart';
import '../models/alert.dart';
import '../models/job.dart';
import '../models/pool_summary.dart';
import '../models/realtime_stats.dart';

/// A signed-in connection to one server.
///
/// It survives the socket: when the phone drops the connection (in the
/// background, or with the screen locked), the next call reconnects and
/// signs in again with the saved credentials.
class TrueNasSession {
  TrueNasSession(
    TrueNasConnection connection,
    this.userInfo, {
    this.instanceId,
    Future<TrueNasConnection> Function()? reconnect,
  }) : _connection = connection {
    client = reconnect == null
        ? connection.client
        : ReconnectingJsonRpcClient(connection.client, () async {
            final next = await reconnect();
            _connection = next;
            return next.client;
          });
  }

  TrueNasConnection _connection;
  final Map<String, dynamic>? userInfo;

  /// The saved server this is a session of, for things that name it later
  /// (a home screen shortcut).
  final String? instanceId;

  /// The connection in use right now; it changes after a reconnect.
  TrueNasConnection get connection => _connection;

  /// Stays the same across reconnects.
  late final JsonRpcClient client;

  late final catalog = MethodCatalog(client);
  late final storage = StorageApi(client, catalog);
  late final sharing = SharingApi(client, catalog);
  late final workloads = WorkloadsApi(client, catalog);
  late final system = SystemApi(client, catalog);
  late final explorer = ExplorerApi(client);
  late final protection = ProtectionApi(client, catalog);
  late final reporting = ReportingApi(client, catalog);

  /// Opens a terminal: the host shell by default, or a VM, app or container
  /// console through [options].
  Future<ShellSession> openShell({Map<String, Object?> options = const {}}) =>
      ShellSession.open(
        client,
        () => connection.openSocket(shellPath),
        options: options,
      );

  String get apiVersion => connection.apiVersion;

  /// Fires after the session reconnected, so screens can reload.
  Stream<void> get reconnected => client.reconnected;

  /// Checks the connection still works, reconnecting if it does not. Called
  /// when the app comes back to the foreground.
  Future<void> ensureAlive() async {
    final client = this.client;
    if (client is ReconnectingJsonRpcClient) await client.ensureAlive();
  }

  Future<Map<String, dynamic>> systemInfo() async =>
      (await client.call('system.info')) as Map<String, dynamic>;

  /// Live CPU, memory, network and ARC statistics, every 2 seconds.
  Stream<RealtimeStats> realtimeStats() => client
      .subscribe('reporting.realtime')
      .where((update) => update.fields != null)
      .map((update) => RealtimeStats.fromJson(update.fields!));

  Future<List<PoolSummary>> pools() async {
    final result = await client.call('pool.query') as List<dynamic>;
    return result
        .map((e) => PoolSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TrueNasAlert>> alerts() async {
    final result = await client.call('alert.list') as List<dynamic>;
    return result
        .map((e) => TrueNasAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Every kind of alert the server can raise, with TrueNAS's own names.
  /// Servers that cannot list them give an empty list.
  Future<List<AlertKind>> alertKinds() async {
    try {
      return AlertKind.fromCategories(
        await client.call('alert.list_categories'),
      );
    } catch (_) {
      return const [];
    }
  }

  /// Fires whenever an alert is added, changed or removed.
  Stream<CollectionUpdate> alertChanges() => client.subscribe('alert.list');

  Future<void> dismissAlert(String id) => client.call('alert.dismiss', [id]);

  Future<void> restoreAlert(String id) => client.call('alert.restore', [id]);

  /// The most recent jobs, newest first.
  Future<List<TrueNasJob>> jobs({int limit = 50}) async {
    final result = await client.call('core.get_jobs', [
      [],
      {
        'order_by': ['-id'],
        'limit': limit,
      },
    ]) as List<dynamic>;
    return result
        .map((e) => TrueNasJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The jobs that are waiting or running now.
  Future<List<TrueNasJob>> activeJobs() => _jobsWhere([
    [
      'state',
      'in',
      ['WAITING', 'RUNNING'],
    ],
  ]);

  /// Jobs by id, finished or not.
  Future<List<TrueNasJob>> jobsById(Iterable<int> ids) => _jobsWhere([
    ['id', 'in', ids.toList()],
  ]);

  Future<List<TrueNasJob>> _jobsWhere(List<Object?> filters) async {
    final result = await client.call('core.get_jobs', [filters]) as List;
    return result
        .map((e) => TrueNasJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Job additions and progress updates.
  Stream<CollectionUpdate> jobChanges() => client.subscribe('core.get_jobs');

  Future<void> abortJob(int id) => client.call('core.job_abort', [id]);

  Future<void> close() => client.close();
}

/// The terminal WebSocket as the TrueNAS web server exposes it. nginx on
/// the NAS forwards it to the middleware's `/_shell`, which is not reachable
/// from outside, so behind a reverse proxy only this path works.
const shellPath = '/websocket/shell/';

/// Thrown when the user cancels a certificate or 2FA prompt.
class ConnectCancelled implements Exception {
  const ConnectCancelled();
}

/// Thrown when the server rejects the saved credentials.
class LoginRejected implements Exception {
  const LoginRejected(this.reason);

  final String reason;
}

/// Asks the user whether to trust a certificate. Returns true to pin it.
typedef ConfirmCertificate = Future<bool> Function(
  UntrustedCertificate certificate,
);

/// Asks the user for a 2FA code. Returns null when cancelled.
typedef AskOtp = Future<String?> Function();

/// Connects and signs in to [instance], asking the user when a certificate
/// needs trusting or a 2FA code is required.
///
/// Returns the session and the instance as it should now be saved (with a
/// newly pinned fingerprint and the API version in use).
Future<(TrueNasSession, ServerInstance)> connectToInstance(
  ServerInstance instance, {
  required ConfirmCertificate confirmCertificate,
  required AskOtp askOtp,
}) async {
  var current = instance;
  TrueNasConnection connection;
  try {
    connection = await TrueNasConnection.open(
      current.address,
      pinnedFingerprint: current.pinnedFingerprint,
    );
  } on UntrustedCertificateException catch (e) {
    if (!await confirmCertificate(e.certificate)) {
      throw const ConnectCancelled();
    }
    current = current.copyWith(
      pinnedFingerprint: () => e.certificate.fingerprint,
    );
    connection = await TrueNasConnection.open(
      current.address,
      pinnedFingerprint: current.pinnedFingerprint,
    );
  }

  try {
    final auth = Authenticator(connection.client);
    var outcome = await auth.login(current.credentials);
    while (outcome is LoginNeedsOtp) {
      final code = await askOtp();
      if (code == null) throw const ConnectCancelled();
      outcome = await auth.submitOtp(code);
    }
    switch (outcome) {
      case LoginSucceeded(:final userInfo):
        current = current.copyWith(lastApiVersion: connection.apiVersion);
        final saved = current;
        return (
          TrueNasSession(
            connection,
            userInfo,
            instanceId: current.id,
            reconnect: () => _reconnect(saved, askOtp),
          ),
          current,
        );
      case LoginFailed(:final reason):
        throw LoginRejected(reason);
      case LoginNeedsOtp():
        throw const ApiException('Unexpected 2FA state');
    }
  } catch (error) {
    _logSignInFailure('Sign-in to "${current.name}"', error);
    await connection.close();
    rethrow;
  }
}

/// Opens a new connection to [instance] and signs in again, for a session
/// whose socket was dropped. The certificate must still match the pinned
/// one; a changed certificate needs the user and fails here.
Future<TrueNasConnection> _reconnect(
  ServerInstance instance,
  AskOtp askOtp,
) async {
  final connection = await TrueNasConnection.open(
    instance.address,
    pinnedFingerprint: instance.pinnedFingerprint,
  );
  try {
    final auth = Authenticator(connection.client);
    var outcome = await auth.login(instance.credentials);
    while (outcome is LoginNeedsOtp) {
      final code = await askOtp();
      if (code == null) throw const ConnectCancelled();
      outcome = await auth.submitOtp(code);
    }
    if (outcome case LoginFailed(:final reason)) throw LoginRejected(reason);
    return connection;
  } catch (error) {
    _logSignInFailure('Signing in again to "${instance.name}"', error);
    await connection.close();
    rethrow;
  }
}

/// A rejected login or an unexpected answer. Cancelling a prompt is not one.
/// The credentials are not part of what is logged.
void _logSignInFailure(String what, Object error) {
  if (error is ConnectCancelled) return;
  final reason = error is LoginRejected ? error.reason : error;
  AppLog.instance.warning('sign-in', '$what failed: $reason');
}
