import '../models/json.dart';
import '../models/sharing.dart';
import 'job_wait.dart';
import 'json_rpc_client.dart';
import 'method_catalog.dart';

enum ServiceAction { start, stop, restart }

/// Services and SMB, NFS, iSCSI and NVMe-oF shares.
class SharingApi {
  SharingApi(this._client, this._catalog);

  final JsonRpcClient _client;
  final MethodCatalog _catalog;

  Future<List<Map<String, dynamic>>> _query(String method) async => [
    for (final e in await _client.call(method) as List<dynamic>) asMap(e),
  ];

  Future<List<ServiceEntry>> services() async =>
      (await _query('service.query')).map(ServiceEntry.fromJson).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

  /// Starts, stops or restarts [service] and waits until it is done.
  ///
  /// 25.10 and newer use the `service.control` job; 25.04 has
  /// `service.start`, `service.stop` and `service.restart` instead.
  Future<void> controlService(String service, ServiceAction action) async {
    final verb = action.name;
    if (await _catalog.has('service.control')) {
      final job = await _client.call('service.control', [
        verb.toUpperCase(),
        service,
        {'silent': false},
      ]);
      await waitForJob(_client, asInt(job));
    } else {
      await _client.call('service.$verb', [
        service,
        {'silent': false},
      ]);
    }
  }

  /// Turns starting on boot on or off.
  Future<void> setServiceAutostart(int id, bool enable) =>
      _client.call('service.update', [
        id,
        {'enable': enable},
      ]);

  Future<List<SmbShare>> smbShares() async =>
      (await _query('sharing.smb.query')).map(SmbShare.fromJson).toList();

  Future<void> createSmbShare({
    required String name,
    required String path,
    String comment = '',
  }) => _client.call('sharing.smb.create', [
    {'name': name, 'path': path, 'comment': comment},
  ]);

  Future<void> updateSmbShare(int id, Map<String, Object?> changes) =>
      _client.call('sharing.smb.update', [id, changes]);

  Future<void> deleteSmbShare(int id) =>
      _client.call('sharing.smb.delete', [id]);

  Future<List<NfsShare>> nfsShares() async =>
      (await _query('sharing.nfs.query')).map(NfsShare.fromJson).toList();

  Future<void> createNfsShare({
    required String path,
    String comment = '',
    bool readOnly = false,
  }) => _client.call('sharing.nfs.create', [
    {'path': path, 'comment': comment, 'ro': readOnly},
  ]);

  Future<void> updateNfsShare(int id, Map<String, Object?> changes) =>
      _client.call('sharing.nfs.update', [id, changes]);

  Future<void> deleteNfsShare(int id) =>
      _client.call('sharing.nfs.delete', [id]);

  Future<List<IscsiTarget>> iscsiTargets() async =>
      (await _query('iscsi.target.query')).map(IscsiTarget.fromJson).toList();

  Future<List<IscsiExtent>> iscsiExtents() async =>
      (await _query('iscsi.extent.query')).map(IscsiExtent.fromJson).toList();

  /// Whether the server has NVMe over Fabrics (25.10 and newer).
  Future<bool> hasNvmet() => _catalog.has('nvmet.subsys.query');

  Future<List<NvmetSubsystem>> nvmetSubsystems() async =>
      (await _query('nvmet.subsys.query'))
          .map(NvmetSubsystem.fromJson)
          .toList();
}
