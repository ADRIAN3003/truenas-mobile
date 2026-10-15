import 'json.dart';

/// A vdev or disk in a pool's topology.
class Vdev {
  const Vdev({
    required this.name,
    required this.type,
    required this.status,
    required this.readErrors,
    required this.writeErrors,
    required this.checksumErrors,
    required this.children,
    this.disk,
  });

  factory Vdev.fromJson(Map<String, dynamic> json) {
    final stats = asMap(json['stats']);
    return Vdev(
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      status: (json['status'] ?? 'UNKNOWN').toString(),
      readErrors: asInt(stats['read_errors']),
      writeErrors: asInt(stats['write_errors']),
      checksumErrors: asInt(stats['checksum_errors']),
      disk: json['disk'] as String?,
      children: [
        for (final child in (json['children'] as List<dynamic>? ?? const []))
          Vdev.fromJson(asMap(child)),
      ],
    );
  }

  final String name;

  /// `MIRROR`, `RAIDZ1`, `RAIDZ2`, `RAIDZ3`, `DRAID…`, `STRIPE` or `DISK`.
  final String type;
  final String status;
  final int readErrors;
  final int writeErrors;
  final int checksumErrors;

  /// The disk name (e.g. `sda`) for leaf vdevs.
  final String? disk;
  final List<Vdev> children;

  int get errors => readErrors + writeErrors + checksumErrors;
  bool get online => status == 'ONLINE';
}

/// The last or current scrub/resilver of a pool.
class PoolScan {
  const PoolScan({
    required this.function,
    required this.state,
    required this.percentage,
    required this.errors,
    required this.paused,
    this.endTime,
  });

  factory PoolScan.fromJson(Map<String, dynamic> json) => PoolScan(
    function: (json['function'] ?? '').toString(),
    state: (json['state'] ?? '').toString(),
    percentage: asDouble(json['percentage']),
    errors: asInt(json['errors']),
    paused: json['pause'] != null,
    endTime: asDate(json['end_time']),
  );

  /// `SCRUB` or `RESILVER`.
  final String function;

  /// `SCANNING`, `FINISHED` or `CANCELED`.
  final String state;
  final double percentage;
  final int errors;
  final bool paused;
  final DateTime? endTime;

  bool get running => state == 'SCANNING';
}

/// A pool from `pool.query`, including its topology.
class PoolDetail {
  const PoolDetail({
    required this.id,
    required this.name,
    required this.status,
    required this.healthy,
    required this.size,
    required this.allocated,
    required this.free,
    required this.topology,
    this.scan,
    this.statusDetail,
  });

  factory PoolDetail.fromJson(Map<String, dynamic> json) {
    final topology = asMap(json['topology']);
    final scan = json['scan'];
    return PoolDetail(
      id: asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      status: (json['status'] ?? 'UNKNOWN').toString(),
      healthy: json['healthy'] == true,
      size: asInt(json['size']),
      allocated: asInt(json['allocated']),
      free: asInt(json['free']),
      statusDetail: json['status_detail'] as String?,
      scan: scan is Map<String, dynamic> ? PoolScan.fromJson(scan) : null,
      topology: {
        for (final group in const [
          'data',
          'log',
          'cache',
          'spare',
          'special',
          'dedup',
        ])
          if ((topology[group] as List<dynamic>? ?? const []).isNotEmpty)
            group: [
              for (final vdev in topology[group] as List<dynamic>)
                Vdev.fromJson(asMap(vdev)),
            ],
      },
    );
  }

  final int id;
  final String name;
  final String status;
  final bool healthy;
  final int size;
  final int allocated;
  final int free;
  final String? statusDetail;
  final PoolScan? scan;

  /// Vdev groups that are present: `data`, `log`, `cache`, `spare`,
  /// `special`, `dedup`.
  final Map<String, List<Vdev>> topology;

  double get usedFraction => size == 0 ? 0 : allocated / size;
}

/// A dataset or zvol from `pool.dataset.query`.
class Dataset {
  const Dataset({
    required this.id,
    required this.pool,
    required this.isVolume,
    required this.used,
    required this.available,
    required this.encrypted,
    required this.locked,
    this.mountpoint,
    this.compression,
    this.compressRatio,
    this.volsize,
  });

  factory Dataset.fromJson(Map<String, dynamic> json) {
    Object? parsed(String key) => asMap(json[key])['parsed'];
    String? value(String key) => asMap(json[key])['value']?.toString();
    final volsize = parsed('volsize');
    return Dataset(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      pool: (json['pool'] ?? '').toString(),
      isVolume: json['type'] == 'VOLUME',
      used: asInt(parsed('used')),
      available: asInt(parsed('available')),
      encrypted: json['encrypted'] == true,
      locked: json['locked'] == true,
      mountpoint: json['mountpoint'] as String?,
      compression: value('compression'),
      compressRatio: value('compressratio'),
      volsize: volsize is num ? volsize.toInt() : null,
    );
  }

  /// Full name, e.g. `tank/media/photos`.
  final String id;
  final String pool;
  final bool isVolume;
  final int used;
  final int available;
  final bool encrypted;
  final bool locked;
  final String? mountpoint;
  final String? compression;
  final String? compressRatio;
  final int? volsize;

  String get shortName => id.split('/').last;

  /// 0 for the pool's root dataset.
  int get depth => '/'.allMatches(id).length;

  bool get isRoot => !id.contains('/');
}

/// A ZFS snapshot.
class Snapshot {
  const Snapshot({
    required this.id,
    required this.dataset,
    required this.name,
    required this.used,
    required this.referenced,
    this.created,
  });

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    final properties = asMap(json['properties']);
    Object? parsed(String key) => asMap(properties[key])['parsed'];
    final id = (json['id'] ?? json['name'] ?? '').toString();
    return Snapshot(
      id: id,
      dataset: (json['dataset'] ?? id.split('@').first).toString(),
      name: (json['snapshot_name'] ?? id.split('@').last).toString(),
      used: asInt(parsed('used')),
      referenced: asInt(parsed('referenced')),
      created: asDate(parsed('creation')),
    );
  }

  /// `dataset@name`.
  final String id;
  final String dataset;
  final String name;
  final int used;
  final int referenced;
  final DateTime? created;
}

/// A physical disk from `disk.query`.
class Disk {
  const Disk({
    required this.name,
    required this.size,
    required this.isSsd,
    this.serial,
    this.model,
    this.pool,
    this.rotationRate,
    this.temperature,
  });

  factory Disk.fromJson(Map<String, dynamic> json) => Disk(
    name: (json['name'] ?? json['devname'] ?? '').toString(),
    size: asInt(json['size']),
    isSsd: json['type'] == 'SSD',
    serial: json['serial'] as String?,
    model: json['model'] as String?,
    pool: json['pool'] as String?,
    rotationRate: json['rotationrate'] is num
        ? (json['rotationrate'] as num).toInt()
        : null,
  );

  final String name;
  final int size;
  final bool isSsd;
  final String? serial;
  final String? model;

  /// Pool the disk belongs to, or null when unused.
  final String? pool;
  final int? rotationRate;

  /// Degrees Celsius, when the server reports it.
  final double? temperature;

  Disk withTemperature(double? value) => Disk(
    name: name,
    size: size,
    isSsd: isSsd,
    serial: serial,
    model: model,
    pool: pool,
    rotationRate: rotationRate,
    temperature: value,
  );
}
