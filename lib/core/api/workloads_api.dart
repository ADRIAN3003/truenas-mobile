import '../models/json.dart';
import '../models/workloads.dart';
import 'job_wait.dart';
import 'json_rpc_client.dart';
import 'method_catalog.dart';

enum WorkloadAction { start, stop, restart, powerOff, upgrade, delete }

/// Which container system the server has.
enum ContainerBackend {
  /// Incus `virt.instance.*` on 25.04 and 25.10.
  incus,

  /// `container.*` on 26 and newer.
  containers,

  none,
}

/// Docker apps, virtual machines and containers.
class WorkloadsApi {
  WorkloadsApi(this._client, this._catalog);

  final JsonRpcClient _client;
  final MethodCatalog _catalog;
  ContainerBackend? _backend;

  /// Calls a job method and waits for it to finish.
  Future<void> _job(
    String method,
    List<Object?> params, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final id = await _client.call(method, params);
    await waitForJob(_client, asInt(id), timeout: timeout);
  }

  Future<List<Map<String, dynamic>>> _query(String method) async => [
    for (final e in await _client.call(method) as List<dynamic>) asMap(e),
  ];

  Future<List<TrueNasApp>> apps() async =>
      (await _query('app.query')).map(TrueNasApp.fromJson).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// start, stop, restart (redeploy), upgrade or delete. Deleting keeps
  /// the app's volumes; only its images are removed.
  Future<void> appAction(String name, WorkloadAction action) =>
      switch (action) {
        WorkloadAction.start => _job('app.start', [name]),
        WorkloadAction.stop => _job('app.stop', [name]),
        WorkloadAction.restart => _job('app.redeploy', [name]),
        WorkloadAction.upgrade => _job('app.upgrade', [
          name,
        ], timeout: const Duration(minutes: 20)),
        WorkloadAction.delete => _job('app.delete', [
          name,
          {'remove_images': true, 'remove_ix_volumes': false},
        ]),
        WorkloadAction.powerOff => throw UnsupportedError('powerOff'),
      };

  Future<List<VirtualMachine>> vms() async =>
      (await _query('vm.query')).map(VirtualMachine.fromJson).toList();

  /// start, stop (graceful, forced after the VM's timeout), restart or
  /// power off.
  Future<void> vmAction(int id, WorkloadAction action) => switch (action) {
    WorkloadAction.start => _client.call('vm.start', [
      id,
      {'overcommit': false},
    ]),
    WorkloadAction.stop => _job('vm.stop', [
      id,
      {'force': false, 'force_after_timeout': true},
    ]),
    WorkloadAction.restart => _job('vm.restart', [id]),
    WorkloadAction.powerOff => _client.call('vm.poweroff', [id]),
    _ => throw UnsupportedError(action.name),
  };

  /// Containers of a running app that a shell can open in, as id → name.
  Future<Map<String, String>> appShellContainers(String app) async {
    final choices = asMap(
      await _client.call('app.container_console_choices', [app]),
    );
    return {
      for (final MapEntry(:key, :value) in choices.entries)
        key: switch (value) {
          final Map<String, dynamic> v =>
            (v['service_name'] ?? v['image'] ?? key).toString(),
          _ => value.toString(),
        },
    };
  }

  /// Shell options for an app container, a VM console or a container.
  static Map<String, Object?> appShell(String app, String containerId) => {
    'app_name': app,
    'container_id': containerId,
  };

  static Map<String, Object?> vmShell(int id) => {'vm_id': id};

  Future<Map<String, Object?>> containerShell(LinuxContainer c) async =>
      await containerBackend() == ContainerBackend.containers
      ? {'container_id': int.parse(c.id)}
      : {'virt_instance_id': c.id};

  Future<ContainerBackend> containerBackend() async =>
      _backend ??= await _catalog.has('container.query')
      ? ContainerBackend.containers
      : await _catalog.has('virt.instance.query')
      ? ContainerBackend.incus
      : ContainerBackend.none;

  Future<List<LinuxContainer>> containers() async =>
      switch (await containerBackend()) {
        ContainerBackend.containers => (await _query(
          'container.query',
        )).map(LinuxContainer.fromContainer).toList(),
        ContainerBackend.incus => (await _query(
          'virt.instance.query',
        )).map(LinuxContainer.fromIncus).toList(),
        ContainerBackend.none => <LinuxContainer>[],
      };

  /// Actions a container supports on this server.
  Future<List<WorkloadAction>> containerActions() async =>
      switch (await containerBackend()) {
        ContainerBackend.incus => const [
          WorkloadAction.start,
          WorkloadAction.stop,
          WorkloadAction.restart,
        ],
        ContainerBackend.containers => const [
          WorkloadAction.start,
          WorkloadAction.stop,
        ],
        ContainerBackend.none => const [],
      };

  Future<void> containerAction(
    LinuxContainer container,
    WorkloadAction action,
  ) async {
    final backend = await containerBackend();
    if (backend == ContainerBackend.containers) {
      final id = int.parse(container.id);
      return switch (action) {
        WorkloadAction.start => _client.call('container.start', [id]),
        WorkloadAction.stop => _job('container.stop', [
          id,
          {'force': false, 'force_after_timeout': true},
        ]),
        _ => throw UnsupportedError(action.name),
      };
    }
    // Incus refuses a graceful stop without a timeout.
    const stopArgs = {'timeout': 60, 'force': false};
    return switch (action) {
      WorkloadAction.start => _job('virt.instance.start', [container.id]),
      WorkloadAction.stop => _job('virt.instance.stop', [
        container.id,
        stopArgs,
      ]),
      WorkloadAction.restart => _job('virt.instance.restart', [
        container.id,
        stopArgs,
      ]),
      _ => throw UnsupportedError(action.name),
    };
  }
}
