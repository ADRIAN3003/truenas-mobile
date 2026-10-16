import 'app_version.dart';

/// A file attached to a GitHub release.
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.url,
    this.size,
    this.sha256,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    // GitHub lists a checksum as "sha256:<hex>" on newer assets.
    final digest = json['digest'] as String?;
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      url: json['browser_download_url'] as String? ?? '',
      size: (json['size'] as num?)?.toInt(),
      sha256: digest != null && digest.startsWith('sha256:')
          ? digest.substring(7).toLowerCase()
          : null,
    );
  }

  final String name;
  final String url;
  final int? size;
  final String? sha256;
}

/// A published GitHub release of the app.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.name,
    required this.notes,
    required this.url,
    required this.assets,
    this.publishedAt,
  });

  /// Null for a release whose tag is not a version number.
  static ReleaseInfo? fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;
    return ReleaseInfo(
      tag: tag,
      version: version,
      name: (json['name'] as String?)?.trim().isNotEmpty ?? false
          ? (json['name'] as String).trim()
          : tag,
      notes: (json['body'] as String? ?? '').trim(),
      url: json['html_url'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      assets: [
        for (final asset in json['assets'] as List<dynamic>? ?? const [])
          ReleaseAsset.fromJson(asset as Map<String, dynamic>),
      ],
    );
  }

  final String tag;
  final AppVersion version;
  final String name;

  /// The release notes, as Markdown. Empty when there are none.
  final String notes;

  /// The release's page on GitHub.
  final String url;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  /// The release workflow names the per-ABI builds
  /// `truenas-mobile-<tag>-<abi>-release.apk` and the universal one
  /// `truenas-mobile-<tag>-release.apk`.
  static final _splitApk = RegExp(
    r'-(arm64-v8a|armeabi-v7a|x86_64|x86)-release\.apk$',
  );

  /// The APK for a phone whose preferred ABIs are [abis] (best first).
  ///
  /// The per-ABI build comes first: its version code is higher than the
  /// universal build's, so it installs over either, while a universal build
  /// would not install over a per-ABI one. The universal APK is the fallback
  /// for an ABI that has no build of its own.
  ReleaseAsset? apkFor(List<String> abis) {
    final apks = [
      for (final asset in assets)
        if (asset.name.endsWith('.apk') && asset.url.isNotEmpty) asset,
    ];
    for (final abi in abis) {
      for (final apk in apks) {
        if (apk.name.endsWith('-$abi-release.apk')) return apk;
      }
    }
    for (final apk in apks) {
      if (!_splitApk.hasMatch(apk.name)) return apk;
    }
    return null;
  }
}
