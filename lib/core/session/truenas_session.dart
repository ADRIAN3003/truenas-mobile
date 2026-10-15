import '../api/api_exception.dart';
import '../api/auth.dart';
import '../api/certificate_trust.dart';
import '../api/events.dart';
import '../api/json_rpc_client.dart';
import '../api/method_catalog.dart';
import '../api/sharing_api.dart';
import '../api/storage_api.dart';
import '../api/truenas_connection.dart';
import '../api/workloads_api.dart';
import '../instances/server_instance.dart';
import '../models/alert.dart';
import '../models/job.dart';
import '../models/pool_summary.dart';
import '../models/realtime_stats.dart';

/// A signed-in connection to one server.
class TrueNasSession {
  TrueNasSession(this.connection, this.userInfo);

  final TrueNasConnection connection;
  final Map<String, dynamic>? userInfo;

  late final catalog = MethodCatalog(client);
  late final storage = StorageApi(client, catalog);
  late final sharing = SharingApi(client, catalog);
  late final workloads = WorkloadsApi(client, catalog);

  String get apiVersion => connection.apiVersion;
  JsonRpcClient get client => connection.client;

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

  /// Job additions and progress updates.
  Stream<CollectionUpdate> jobChanges() => client.subscribe('core.get_jobs');

  Future<void> abortJob(int id) => client.call('core.job_abort', [id]);

  Future<void> close() => connection.close();
}

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
        return (TrueNasSession(connection, userInfo), current);
      case LoginFailed(:final reason):
        throw LoginRejected(reason);
      case LoginNeedsOtp():
        throw const ApiException('Unexpected 2FA state');
    }
  } catch (_) {
    await connection.close();
    rethrow;
  }
}
