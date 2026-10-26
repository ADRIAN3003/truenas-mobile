import 'dart:async';
import 'dart:convert';

import '../models/app_catalog.dart';
import '../models/job.dart';
import '../models/json.dart';
import '../models/workloads.dart';
import 'api_exception.dart';
import 'events.dart';
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

  /// Whether the server can run one action over several apps in one job.
  Future<bool> canBulk() => _catalog.has('core.bulk');

  /// Starts one `core.bulk` job that does [action] to every app in [names], as
  /// the web UI's "Update All" does, and returns its id. The server does the
  /// work, so it carries on when the phone is locked or the app is closed.
  Future<int> bulk(AppBulkAction action, List<String> names) async => asInt(
    await _client.call('core.bulk', [
      action.method,
      [
        for (final name in names) [name],
      ],
    ]),
  );

  /// The bulk run behind job [id], or null when the server no longer lists
  /// it or it is not a bulk run over apps.
  Future<AppBulkRun?> bulkRun(int id) async {
    final jobs = await _client.call('core.get_jobs', [
      [
        ['id', '=', id],
      ],
    ]) as List<dynamic>;
    return jobs.isEmpty ? null : AppBulkRun.fromJob(asMap(jobs.first));
  }

  /// The bulk run in progress, started from here or from the web UI.
  Future<AppBulkRun?> activeBulkRun() async {
    final jobs = await _client.call('core.get_jobs', [
      [
        ['method', '=', 'core.bulk'],
      ],
      {
        'order_by': ['-id'],
        'limit': 20,
      },
    ]) as List<dynamic>;
    for (final raw in jobs) {
      final run = AppBulkRun.fromJob(asMap(raw));
      if (run != null && run.isActive) return run;
    }
    return null;
  }

  /// Whether apps can be installed from the catalog from here.
  Future<bool> canInstall() async =>
      await _catalog.has('app.create') &&
      await _catalog.has('app.available') &&
      await _catalog.has('catalog.get_app_details');

  /// Whether an installed app's configuration can be changed from here.
  Future<bool> canEdit() async =>
      await _catalog.has('app.update') && await _catalog.has('app.config');

  /// Whether the catalog can be refreshed from its source.
  Future<bool> canSyncCatalog() => _catalog.has('catalog.sync');

  /// Where Docker stands. Installing needs it running, and it only runs once
  /// a pool is chosen for apps. [DockerState.unknown] when the server doesn't
  /// say.
  Future<DockerState> dockerState() async {
    if (!await _catalog.has('docker.status')) return DockerState.unknown;
    try {
      return DockerState.parse(
        asMap(await _client.call('docker.status'))['status'],
      );
    } catch (_) {
      return DockerState.unknown;
    }
  }

  /// Every app the catalog offers, by title.
  Future<List<CatalogApp>> catalogApps() async =>
      (await _query('app.available')).map(CatalogApp.fromJson).toList()..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

  /// An app with the form of each of its versions.
  Future<CatalogAppDetails> catalogDetails(String name, String train) async =>
      CatalogAppDetails.fromJson(
        asMap(
          await _client.call('catalog.get_app_details', [
            name,
            {'train': train},
          ]),
        ),
      );

  /// Pulls the catalog's newest content from its source.
  Future<void> syncCatalog() => _job('catalog.sync', const []);

  /// The values an installed app runs with.
  Future<Map<String, dynamic>> appConfig(String name) async =>
      asMap(await _client.call('app.config', [name]));

  /// Starts installing [catalogApp] as an app called [name] and returns the
  /// job. Pulling images takes a while; see [settleJob].
  Future<int> installApp({
    required String name,
    required String catalogApp,
    required String train,
    required String version,
    required Map<String, dynamic> values,
  }) async => asInt(
    await _client.call('app.create', [
      {
        'app_name': name,
        'train': train,
        'catalog_app': catalogApp,
        'version': version,
        'values': values,
      },
    ]),
  );

  /// Starts installing a custom app from a Docker Compose file.
  Future<int> installCustomApp({
    required String name,
    required String compose,
  }) async => asInt(
    await _client.call('app.create', [
      {
        'app_name': name,
        'custom_app': true,
        'custom_compose_config_string': compose,
      },
    ]),
  );

  /// Starts applying new [values] to an installed app (or a new Compose
  /// config, for a custom one) and returns the job.
  Future<int> updateApp(
    String name, {
    Map<String, dynamic>? values,
    Map<String, dynamic>? compose,
  }) async => asInt(
    await _client.call('app.update', [
      name,
      {'values': ?values, 'custom_compose_config': ?compose},
    ]),
  );

  /// How long [settleJob] waits by default. Tests shorten it.
  static Duration settleWindow = const Duration(seconds: 10);

  /// Waits up to [within] for job [id]: true once it succeeded, false when it
  /// still runs (installing and redeploying can take minutes). Throws an
  /// [ApiException] with the job's error when it failed, which is how a
  /// refused configuration shows, usually within a second.
  Future<bool> settleJob(
    int id, {
    Duration? within,
    Duration poll = const Duration(milliseconds: 500),
  }) async {
    final deadline = DateTime.now().add(within ?? settleWindow);
    while (true) {
      final jobs = await _client.call('core.get_jobs', [
        [
          ['id', '=', id],
        ],
      ]) as List<dynamic>;
      if (jobs.isNotEmpty) {
        final job = TrueNasJob.fromJson(asMap(jobs.first));
        switch (job.state) {
          case JobState.success:
            return true;
          case JobState.failed || JobState.aborted:
            throw ApiException(job.error ?? job.state.name);
          case JobState.waiting || JobState.running:
            break;
        }
      }
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(poll);
    }
  }

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

  /// The output of one app container: the last [tailLines] lines, then new
  /// ones as they are written, from the `app.container_log_follow` event
  /// source (what the web UI's log viewer reads). Cancel to stop following.
  Stream<AppLogLine> appLogs(
    String app,
    String containerId, {
    int tailLines = 500,
  }) {
    final args = jsonEncode({
      'app_name': app,
      'container_id': containerId,
      'tail_lines': tailLines,
    });
    return _client
        .subscribe('app.container_log_follow:$args')
        .map((update) => AppLogLine.fromFields(update.fields))
        .where((line) => line != null)
        .cast<AppLogLine>();
  }

  /// Shell options for an app container, a VM console or a container.
  static Map<String, Object?> appShell(String app, String containerId) => {
    'app_name': app,
    'container_id': containerId,
  };

  static Map<String, Object?> vmShell(int id) => {'vm_id': id};

  /// What an app or container shell tries when the image has no bash, which
  /// is the server's default. Lean images such as Alpine only have `sh`.
  static const shellFallbacks = ['/bin/sh'];

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

/// One line of an app container's output.
class AppLogLine {
  const AppLogLine(this.text, {this.time});

  /// Null when the event carries no text.
  static AppLogLine? fromFields(Map<String, dynamic>? fields) {
    final data = fields?['data'];
    if (data == null) return null;
    final time = fields?['timestamp'];
    return AppLogLine(
      _stripAnsi(data.toString()).trimRight(),
      time: switch (time) {
        final Map<String, dynamic> m when m[r'$date'] is int =>
          DateTime.fromMillisecondsSinceEpoch(m[r'$date'] as int),
        final String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }

  final String text;
  final DateTime? time;

  /// Colour codes and cursor moves that apps print to a terminal.
  static final _ansi = RegExp('\x1B\\[[0-9;?]*[ -/]*[@-~]');

  static String _stripAnsi(String text) => text.replaceAll(_ansi, '');
}
