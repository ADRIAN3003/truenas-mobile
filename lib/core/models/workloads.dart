import 'job.dart';
import 'json.dart';

/// Normalised run state shared by apps, VMs and containers.
enum WorkloadState {
  running,
  stopped,
  deploying,
  stopping,
  suspended,
  crashed,
  unknown;

  static WorkloadState parse(Object? value) =>
      switch (value?.toString().toUpperCase()) {
        'RUNNING' => running,
        'STOPPED' => stopped,
        'DEPLOYING' || 'STARTING' => deploying,
        'STOPPING' || 'ABORTING' => stopping,
        'SUSPENDED' || 'FROZEN' || 'FREEZING' => suspended,
        'CRASHED' || 'ERROR' => crashed,
        _ => unknown,
      };

  bool get isUp => this == running || this == deploying;
}

/// A Docker app from `app.query`.
class TrueNasApp {
  const TrueNasApp({
    required this.name,
    required this.state,
    required this.version,
    required this.upgradeAvailable,
    required this.imageUpdatesAvailable,
    required this.customApp,
    required this.containers,
    required this.portals,
    required this.images,
    this.chartVersion,
    this.latestVersion,
    this.title,
    this.iconUrl,
    this.notes,
  });

  factory TrueNasApp.fromJson(Map<String, dynamic> json) {
    final metadata = asMap(json['metadata']);
    final workloads = asMap(json['active_workloads']);
    return TrueNasApp(
      name: (json['name'] ?? json['id'] ?? '').toString(),
      state: WorkloadState.parse(json['state']),
      version: (json['human_version'] ?? json['version'] ?? '').toString(),
      chartVersion: json['version'] as String?,
      latestVersion: json['latest_version'] as String?,
      upgradeAvailable: json['upgrade_available'] == true,
      imageUpdatesAvailable: json['image_updates_available'] == true,
      customApp: json['custom_app'] == true,
      containers: asInt(workloads['containers']),
      images: [
        for (final image in workloads['images'] as List<dynamic>? ?? const [])
          image.toString(),
      ],
      portals: {
        for (final MapEntry(:key, :value) in asMap(json['portals']).entries)
          key: value.toString(),
      },
      title: metadata['title'] as String?,
      iconUrl: metadata['icon'] as String?,
      notes: json['notes'] as String?,
    );
  }

  /// The instance name chosen at install, also its id.
  final String name;
  final WorkloadState state;
  final String version;

  /// The installed catalog version (`1.2.3`), the kind [latestVersion] is;
  /// [version] is the longer human one (`10.10.7_1.2.3`).
  final String? chartVersion;
  final String? latestVersion;
  final bool upgradeAvailable;
  final bool imageUpdatesAvailable;
  final bool customApp;

  /// Running containers.
  final int containers;
  final List<String> images;

  /// Web interfaces by label, e.g. `{"Web UI": "http://nas:30000/"}`.
  final Map<String, String> portals;

  /// Catalog title, e.g. "Jellyfin".
  final String? title;
  final String? iconUrl;
  final String? notes;
}

/// An "Update all" run: the server's `core.bulk` job over `app.upgrade`. It
/// lives on the server, so it carries on when the app is closed and can be
/// found again by its [jobId] or by [AppUpdateRun.fromJob] on any `core.bulk`
/// job.
class AppUpdateRun {
  const AppUpdateRun({required this.job, required this.apps});

  /// Null when [job] is not a bulk upgrade.
  static AppUpdateRun? fromJob(Map<String, dynamic> json) {
    final arguments = json['arguments'];
    if (json['method'] != 'core.bulk' ||
        arguments is! List ||
        arguments.length < 2 ||
        arguments[0] != 'app.upgrade' ||
        arguments[1] is! List) {
      return null;
    }
    return AppUpdateRun(
      job: TrueNasJob.fromJson(json),
      apps: [
        for (final call in arguments[1] as List)
          if (call is List && call.isNotEmpty) call.first.toString(),
      ],
    );
  }

  /// The `core.bulk` job, for progress and the end state.
  final TrueNasJob job;

  /// The apps it updates, in order.
  final List<String> apps;

  int get jobId => job.id;
  bool get isActive => job.state.isActive;

  /// Apps the server could not update, with its reason. Empty while the job
  /// runs. When the job itself failed or was aborted no per-app result is
  /// trustworthy, so every app is listed.
  Map<String, String> get failed {
    if (isActive) return const {};
    final results = job.raw['result'];
    if (job.state == JobState.success && results is List) {
      return {
        for (var i = 0; i < apps.length && i < results.length; i++)
          if (results[i] case {'error': final Object error})
            apps[i]: error.toString(),
      };
    }
    if (job.state == JobState.success) return const {};
    return {for (final app in apps) app: job.error ?? job.state.name};
  }
}

/// A virtual machine from `vm.query`.
class VirtualMachine {
  const VirtualMachine({
    required this.id,
    required this.name,
    required this.description,
    required this.state,
    required this.vcpus,
    required this.memoryMib,
    required this.autostart,
  });

  factory VirtualMachine.fromJson(Map<String, dynamic> json) {
    final vcpus = asInt(json['vcpus']);
    final cores = asInt(json['cores']);
    final threads = asInt(json['threads']);
    return VirtualMachine(
      id: asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      state: WorkloadState.parse(asMap(json['status'])['state']),
      vcpus:
          (vcpus == 0 ? 1 : vcpus) *
          (cores == 0 ? 1 : cores) *
          (threads == 0 ? 1 : threads),
      memoryMib: asInt(json['memory']),
      autostart: json['autostart'] == true,
    );
  }

  final int id;
  final String name;
  final String description;
  final WorkloadState state;

  /// Total virtual CPUs (sockets × cores × threads).
  final int vcpus;
  final int memoryMib;
  final bool autostart;
}

/// A Linux container: an Incus instance (`virt.instance`, 25.04/25.10) or a
/// `container` (26 and newer).
class LinuxContainer {
  const LinuxContainer({
    required this.id,
    required this.name,
    required this.state,
    required this.isVm,
    required this.autostart,
    this.description,
  });

  /// From `virt.instance.query`.
  factory LinuxContainer.fromIncus(Map<String, dynamic> json) {
    final image = asMap(json['image']);
    final os = [image['os'], image['release']].whereType<String>().join(' ');
    return LinuxContainer(
      id: (json['id'] ?? json['name']).toString(),
      name: (json['name'] ?? '').toString(),
      state: WorkloadState.parse(json['status']),
      isVm: json['type'] == 'VM',
      autostart: json['autostart'] == true,
      description: os.isEmpty ? null : os,
    );
  }

  /// From `container.query`.
  factory LinuxContainer.fromContainer(Map<String, dynamic> json) {
    final description = (json['description'] ?? '').toString();
    return LinuxContainer(
      id: asInt(json['id']).toString(),
      name: (json['name'] ?? '').toString(),
      state: WorkloadState.parse(asMap(json['status'])['state']),
      isVm: false,
      autostart: json['autostart'] == true,
      description: description.isEmpty ? null : description,
    );
  }

  /// A string for Incus, a number (as text) for `container`.
  final String id;
  final String name;
  final WorkloadState state;

  /// Incus could also run VMs; they are listed with containers there.
  final bool isVm;
  final bool autostart;
  final String? description;
}
