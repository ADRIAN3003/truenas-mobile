import 'json.dart';

/// A local user from `user.query`.
class LocalUser {
  const LocalUser({
    required this.id,
    required this.uid,
    required this.username,
    required this.fullName,
    required this.builtin,
    required this.locked,
    required this.smb,
    required this.twoFactor,
    this.email,
  });

  factory LocalUser.fromJson(Map<String, dynamic> json) => LocalUser(
    id: asInt(json['id']),
    uid: asInt(json['uid']),
    username: (json['username'] ?? '').toString(),
    fullName: (json['full_name'] ?? '').toString(),
    builtin: json['builtin'] == true,
    locked: json['locked'] == true,
    smb: json['smb'] == true,
    twoFactor: json['twofactor_auth_configured'] == true,
    email: json['email'] as String?,
  );

  final int id;
  final int uid;
  final String username;
  final String fullName;

  /// System accounts such as `root` or `daemon`.
  final bool builtin;
  final bool locked;
  final bool smb;
  final bool twoFactor;
  final String? email;
}

/// A local group from `group.query`.
class LocalGroup {
  const LocalGroup({
    required this.id,
    required this.gid,
    required this.name,
    required this.builtin,
    required this.members,
  });

  factory LocalGroup.fromJson(Map<String, dynamic> json) => LocalGroup(
    id: asInt(json['id']),
    gid: asInt(json['gid']),
    name: (json['name'] ?? json['group'] ?? '').toString(),
    builtin: json['builtin'] == true,
    members: (json['users'] as List<dynamic>? ?? const []).length,
  );

  final int id;
  final int gid;
  final String name;
  final bool builtin;
  final int members;
}

/// An API key from `api_key.query`. The secret itself is only returned
/// once, by `api_key.create`.
class ApiKeyInfo {
  const ApiKeyInfo({
    required this.id,
    required this.name,
    required this.revoked,
    this.username,
    this.createdAt,
    this.expiresAt,
  });

  factory ApiKeyInfo.fromJson(Map<String, dynamic> json) => ApiKeyInfo(
    id: asInt(json['id']),
    name: (json['name'] ?? '').toString(),
    username: json['username'] as String?,
    revoked: json['revoked'] == true,
    createdAt: asDate(json['created_at']),
    expiresAt: asDate(json['expires_at']),
  );

  final int id;
  final String name;
  final String? username;
  final bool revoked;
  final DateTime? createdAt;
  final DateTime? expiresAt;
}

/// Addresses, gateways and DNS servers from `network.general.summary`.
class NetworkSummary {
  const NetworkSummary({
    required this.addresses,
    required this.defaultRoutes,
    required this.nameservers,
  });

  factory NetworkSummary.fromJson(Map<String, dynamic> json) {
    final addresses = <String, List<String>>{};
    for (final MapEntry(:key, :value) in asMap(json['ips']).entries) {
      final ips = asMap(value);
      addresses[key] = [
        for (final family in const ['IPV4', 'IPV6'])
          for (final ip in ips[family] as List<dynamic>? ?? const [])
            ip.toString(),
      ];
    }
    return NetworkSummary(
      addresses: addresses,
      defaultRoutes: _strings(json['default_routes']),
      nameservers: _strings(json['nameservers']),
    );
  }

  /// Interface name to its addresses (CIDR form).
  final Map<String, List<String>> addresses;
  final List<String> defaultRoutes;
  final List<String> nameservers;
}

/// A network interface from `interface.query`.
class NetInterface {
  const NetInterface({
    required this.name,
    required this.type,
    required this.linkUp,
    required this.dhcp,
    this.description,
    this.mtu,
    this.mac,
  });

  factory NetInterface.fromJson(Map<String, dynamic> json) {
    final state = asMap(json['state']);
    final description = (json['description'] ?? '').toString();
    return NetInterface(
      name: (json['name'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      linkUp: state['link_state'] == 'LINK_STATE_UP',
      dhcp: json['ipv4_dhcp'] == true,
      description: description.isEmpty ? null : description,
      mtu: state['mtu'] is num ? (state['mtu'] as num).toInt() : null,
      mac: _macOf(state),
    );
  }

  final String name;

  /// `PHYSICAL`, `BRIDGE`, `LINK_AGGREGATION` or `VLAN`.
  final String type;
  final bool linkUp;
  final bool dhcp;
  final String? description;
  final int? mtu;

  /// The card's own MAC address (what Wake-on-LAN needs), when known.
  final String? mac;
}

String? _macOf(Map<String, dynamic> state) {
  for (final key in ['hardware_link_address', 'link_address']) {
    final value = state[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

/// A certificate from `certificate.query`.
class CertificateInfo {
  const CertificateInfo({
    required this.id,
    required this.name,
    required this.expired,
    this.commonName,
    this.until,
    this.san = const [],
  });

  factory CertificateInfo.fromJson(Map<String, dynamic> json) =>
      CertificateInfo(
        id: asInt(json['id']),
        name: (json['name'] ?? '').toString(),
        commonName: json['common'] as String?,
        until: json['until'] as String?,
        expired: json['expired'] == true,
        san: _strings(json['san']),
      );

  final int id;
  final String name;
  final String? commonName;

  /// Expiry as the server formats it, e.g. `Tue Oct 13 08:00:00 2026`.
  final String? until;
  final bool expired;
  final List<String> san;
}

/// A boot environment from `boot.environment.query`.
class BootEnvironment {
  const BootEnvironment({
    required this.id,
    required this.active,
    required this.activated,
    required this.keep,
    required this.canActivate,
    required this.usedBytes,
    this.created,
  });

  factory BootEnvironment.fromJson(Map<String, dynamic> json) =>
      BootEnvironment(
        id: (json['id'] ?? '').toString(),
        active: json['active'] == true,
        activated: json['activated'] == true,
        keep: json['keep'] == true,
        canActivate: json['can_activate'] != false,
        usedBytes: asInt(json['used_bytes']),
        created: asDate(json['created']),
      );

  final String id;

  /// Running now.
  final bool active;

  /// Used on the next boot.
  final bool activated;

  /// Protected from automatic clean-up.
  final bool keep;
  final bool canActivate;
  final int usedBytes;
  final DateTime? created;
}

/// Whether a TrueNAS update is available, normalised across versions.
class UpdateInfo {
  const UpdateInfo({
    required this.available,
    required this.rebootRequired,
    this.version,
    this.releaseNotesUrl,
    this.changelog,
    this.sizeBytes,
    this.error,
  });

  /// From `update.status` (25.10 and newer).
  factory UpdateInfo.fromStatus(Map<String, dynamic> json) {
    final status = asMap(json['status']);
    final newVersion = asMap(status['new_version']);
    final error = asMap(json['error']);
    return UpdateInfo(
      available: newVersion.isNotEmpty,
      rebootRequired: json['code'] == 'REBOOT_REQUIRED',
      version: newVersion['version'] as String?,
      releaseNotesUrl: newVersion['release_notes_url'] as String?,
      changelog: _text(newVersion['changelog']),
      sizeBytes: _bytes(newVersion['filesize']),
      error: json['code'] == 'ERROR' ? error['reason'] as String? : null,
    );
  }

  /// From `update.check_available` (25.04).
  factory UpdateInfo.fromCheck(Map<String, dynamic> json) => UpdateInfo(
    available: json['status'] == 'AVAILABLE',
    rebootRequired: json['status'] == 'REBOOT_REQUIRED',
    version: json['version'] as String?,
    releaseNotesUrl: json['release_notes_url'] as String?,
    changelog: _text(json['changelog']),
    sizeBytes: _bytes(json['filesize']),
  );

  final bool available;

  /// An update was applied and takes effect after a restart.
  final bool rebootRequired;
  final String? version;
  final String? releaseNotesUrl;

  /// What changed, as the server words it. Absent on many servers.
  final String? changelog;

  /// Size of the download, when the server says.
  final int? sizeBytes;
  final String? error;
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _bytes(Object? value) => value is num && value > 0 ? value.toInt() : null;

List<String> _strings(Object? value) => [
  if (value is List)
    for (final v in value) v.toString(),
];
