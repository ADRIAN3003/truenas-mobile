import 'json.dart';

/// A system service from `service.query`.
class ServiceEntry {
  const ServiceEntry({
    required this.id,
    required this.service,
    required this.enable,
    required this.state,
  });

  factory ServiceEntry.fromJson(Map<String, dynamic> json) => ServiceEntry(
    id: asInt(json['id']),
    service: (json['service'] ?? '').toString(),
    enable: json['enable'] == true,
    state: (json['state'] ?? 'UNKNOWN').toString(),
  );

  final int id;

  /// Internal name, e.g. `cifs`, `nfs`, `ssh`.
  final String service;

  /// Starts on boot.
  final bool enable;

  /// `RUNNING`, `STOPPED`, `CRASHED`, …
  final String state;

  bool get running => state == 'RUNNING';

  /// A readable name; these are protocol names, so they are not translated.
  String get displayName => switch (service) {
    'cifs' => 'SMB',
    'iscsitarget' => 'iSCSI',
    'nvmet' => 'NVMe-oF',
    'smartd' => 'S.M.A.R.T.',
    'webshare' => 'WebShare',
    'netdata' => 'Netdata',
    'truecommand' => 'TrueCommand',
    _ => service.toUpperCase(),
  };
}

/// An SMB share from `sharing.smb.query`.
class SmbShare {
  const SmbShare({
    required this.id,
    required this.name,
    required this.path,
    required this.enabled,
    required this.comment,
    required this.readOnly,
    required this.readOnlyKey,
    required this.browsable,
    required this.locked,
    this.purpose,
  });

  factory SmbShare.fromJson(Map<String, dynamic> json) {
    // 25.04 calls the read-only flag `ro`; 25.10 and newer call it `readonly`.
    final readOnlyKey = json.containsKey('readonly') ? 'readonly' : 'ro';
    return SmbShare(
      id: asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      enabled: json['enabled'] != false,
      comment: (json['comment'] ?? '').toString(),
      readOnly: json[readOnlyKey] == true,
      readOnlyKey: readOnlyKey,
      browsable: json['browsable'] != false,
      locked: json['locked'] == true,
      purpose: json['purpose'] as String?,
    );
  }

  final int id;
  final String name;
  final String path;
  final bool enabled;
  final String comment;
  final bool readOnly;

  /// The field name this server uses for [readOnly].
  final String readOnlyKey;
  final bool browsable;

  /// The share's dataset is encrypted and locked.
  final bool locked;
  final String? purpose;
}

/// An NFS export from `sharing.nfs.query`.
class NfsShare {
  const NfsShare({
    required this.id,
    required this.path,
    required this.enabled,
    required this.comment,
    required this.readOnly,
    required this.networks,
    required this.hosts,
    required this.locked,
  });

  factory NfsShare.fromJson(Map<String, dynamic> json) => NfsShare(
    id: asInt(json['id']),
    path: (json['path'] ?? '').toString(),
    enabled: json['enabled'] != false,
    comment: (json['comment'] ?? '').toString(),
    readOnly: json['ro'] == true,
    networks: _strings(json['networks']),
    hosts: _strings(json['hosts']),
    locked: json['locked'] == true,
  );

  final int id;
  final String path;
  final bool enabled;
  final String comment;
  final bool readOnly;

  /// Allowed networks in CIDR form; empty means everyone.
  final List<String> networks;

  /// Allowed host names or addresses; empty means everyone.
  final List<String> hosts;
  final bool locked;
}

/// An iSCSI target from `iscsi.target.query`.
class IscsiTarget {
  const IscsiTarget({
    required this.id,
    required this.name,
    this.alias,
    this.mode,
  });

  factory IscsiTarget.fromJson(Map<String, dynamic> json) => IscsiTarget(
    id: asInt(json['id']),
    name: (json['name'] ?? '').toString(),
    alias: json['alias'] as String?,
    mode: json['mode'] as String?,
  );

  final int id;
  final String name;
  final String? alias;

  /// `ISCSI`, `FC` or `BOTH`.
  final String? mode;
}

/// An iSCSI extent (the zvol or file behind a LUN).
class IscsiExtent {
  const IscsiExtent({
    required this.id,
    required this.name,
    required this.type,
    required this.enabled,
    required this.readOnly,
    this.source,
  });

  factory IscsiExtent.fromJson(Map<String, dynamic> json) => IscsiExtent(
    id: asInt(json['id']),
    name: (json['name'] ?? '').toString(),
    type: (json['type'] ?? 'DISK').toString(),
    enabled: json['enabled'] != false,
    readOnly: json['ro'] == true,
    source: (json['type'] == 'FILE' ? json['path'] : json['disk']) as String?,
  );

  final int id;
  final String name;

  /// `DISK` (a zvol) or `FILE`.
  final String type;
  final bool enabled;
  final bool readOnly;

  /// The zvol (`zvol/tank/vm`) or file path.
  final String? source;
}

/// An NVMe-oF subsystem from `nvmet.subsys.query` (25.10 and newer).
class NvmetSubsystem {
  const NvmetSubsystem({
    required this.id,
    required this.name,
    required this.allowAnyHost,
    this.nqn,
  });

  factory NvmetSubsystem.fromJson(Map<String, dynamic> json) => NvmetSubsystem(
    id: asInt(json['id']),
    name: (json['name'] ?? '').toString(),
    nqn: json['subnqn'] as String?,
    allowAnyHost: json['allow_any_host'] == true,
  );

  final int id;
  final String name;
  final String? nqn;
  final bool allowAnyHost;
}

List<String> _strings(Object? value) => [
  if (value is List)
    for (final v in value) v.toString(),
];
