import 'json.dart';

/// Kinds of device a virtual machine can have (`vm.device` `dtype`).
enum VmDeviceType {
  disk('DISK'),
  raw('RAW'),
  cdrom('CDROM'),
  nic('NIC'),
  display('DISPLAY'),
  pci('PCI'),
  usb('USB');

  const VmDeviceType(this.value);

  final String value;

  static VmDeviceType? parse(Object? value) =>
      values.where((t) => t.value == value).firstOrNull;
}

/// A device of a virtual machine, from `vm.device.query`.
class VmDevice {
  const VmDevice({
    required this.id,
    required this.dtype,
    required this.attributes,
    required this.order,
  });

  /// TrueNAS 25.04 and newer put `dtype` inside `attributes`; older releases
  /// had it beside them. Either is read, and it is kept in `attributes`.
  factory VmDevice.fromJson(Map<String, dynamic> json) {
    final attributes = {...asMap(json['attributes'])};
    final dtype = (attributes['dtype'] ?? json['dtype'] ?? '').toString();
    if (dtype.isNotEmpty) attributes['dtype'] = dtype;
    return VmDevice(
      id: asInt(json['id']),
      dtype: dtype,
      attributes: attributes,
      order: json['order'] is num ? asInt(json['order']) : null,
    );
  }

  final int id;

  /// `DISK`, `NIC`, … as the server writes it.
  final String dtype;
  final Map<String, dynamic> attributes;
  final int? order;

  VmDeviceType? get type => VmDeviceType.parse(dtype);

  /// The one-line detail shown under the device's name: a path, a network
  /// attachment, a resolution.
  String get detail {
    final a = attributes;
    String text(String key) => (a[key] ?? '').toString();
    return switch (type) {
      VmDeviceType.disk ||
      VmDeviceType.raw ||
      VmDeviceType.cdrom => [text('path')].where((s) => s.isNotEmpty).join(),
      VmDeviceType.nic => [
        text('nic_attach'),
        text('mac'),
      ].where((s) => s.isNotEmpty).join(' · '),
      VmDeviceType.display => [
        text('type'),
        text('resolution'),
      ].where((s) => s.isNotEmpty).join(' · '),
      VmDeviceType.pci => text('pptdev'),
      VmDeviceType.usb => [
        text('device'),
        text('controller_type'),
      ].where((s) => s.isNotEmpty).join(' · '),
      null => '',
    };
  }
}

/// What the server offers to pick from in the VM editors. A map is value →
/// label; one that could not be read is empty and the editor falls back to a
/// text field.
class VmChoices {
  const VmChoices({
    this.bootloaders = const {},
    this.cpuModels = const {},
    this.nicAttach = const {},
    this.disks = const {},
    this.resolutions = const [],
    this.binds = const {},
    this.maxVcpus,
  });

  final Map<String, String> bootloaders;
  final Map<String, String> cpuModels;
  final Map<String, String> nicAttach;

  /// Existing zvols, `/dev/zvol/tank/vm` → `tank/vm`.
  final Map<String, String> disks;
  final List<String> resolutions;
  final Map<String, String> binds;

  /// The most vCPUs the host allows in one VM.
  final int? maxVcpus;
}

/// The editable part of a virtual machine (`vm.create` / `vm.update`).
/// Fields the app does not show (CPU pinning, UUID, machine type…) are left
/// as they are on update.
class VmDraft {
  VmDraft();

  factory VmDraft.fromJson(Map<String, dynamic> json) {
    int number(String key, int fallback) =>
        json[key] is num ? asInt(json[key]) : fallback;
    return VmDraft()
      ..name = (json['name'] ?? '').toString()
      ..description = (json['description'] ?? '').toString()
      ..vcpus = number('vcpus', 1)
      ..cores = number('cores', 1)
      ..threads = number('threads', 1)
      ..memory = number('memory', 2048)
      ..minMemory = json['min_memory'] is num ? asInt(json['min_memory']) : null
      ..autostart = json['autostart'] != false
      ..time = (json['time'] ?? 'LOCAL').toString()
      ..bootloader = (json['bootloader'] ?? 'UEFI').toString()
      ..cpuMode = (json['cpu_mode'] ?? 'CUSTOM').toString()
      ..cpuModel = json['cpu_model'] as String?
      ..shutdownTimeout = number('shutdown_timeout', 90)
      ..hideFromMsr = json['hide_from_msr'] == true
      ..ensureDisplayDevice = json['ensure_display_device'] != false
      ..hypervEnlightenments = json['hyperv_enlightenments'] == true
      ..trustedPlatformModule = json.containsKey('trusted_platform_module')
          ? json['trusted_platform_module'] == true
          : null;
  }

  String name = '';
  String description = '';
  int vcpus = 1;
  int cores = 2;
  int threads = 1;

  /// MiB.
  int memory = 2048;

  /// MiB; null when the VM has a fixed amount.
  int? minMemory;
  bool autostart = true;

  /// `LOCAL` or `UTC`: which time the guest's clock is set to.
  String time = 'LOCAL';
  String bootloader = 'UEFI';

  /// `CUSTOM`, `HOST-MODEL` or `HOST-PASSTHROUGH`.
  String cpuMode = 'CUSTOM';
  String? cpuModel;

  /// Seconds the guest gets to shut down before it is powered off.
  int shutdownTimeout = 90;
  bool hideFromMsr = false;
  bool ensureDisplayDevice = true;
  bool hypervEnlightenments = false;

  /// Null when the server has no such setting, so nothing is sent.
  bool? trustedPlatformModule;

  /// Total virtual CPUs.
  int get totalCpus => vcpus * cores * threads;

  Map<String, dynamic> toPayload() => {
    'name': name,
    'description': description,
    'vcpus': vcpus,
    'cores': cores,
    'threads': threads,
    'memory': memory,
    'min_memory': minMemory,
    'autostart': autostart,
    'time': time,
    'bootloader': bootloader,
    'cpu_mode': cpuMode,
    'cpu_model': cpuMode == 'CUSTOM' ? cpuModel : null,
    'shutdown_timeout': shutdownTimeout,
    'hide_from_msr': hideFromMsr,
    'ensure_display_device': ensureDisplayDevice,
    'hyperv_enlightenments': hypervEnlightenments,
    'trusted_platform_module': ?trustedPlatformModule,
  };

  /// Only what differs from [original] (a `vm.query` row), which is all
  /// `vm.update` needs.
  Map<String, dynamic> changesFrom(Map<String, dynamic> original) {
    final changes = <String, dynamic>{};
    for (final MapEntry(:key, :value) in toPayload().entries) {
      final before = original[key];
      final same =
          before == value ||
          (before is num && value is num && before == value) ||
          (before == null && value == '');
      if (!same) changes[key] = value;
    }
    return changes;
  }
}
