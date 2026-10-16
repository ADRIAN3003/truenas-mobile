import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// The phone's own language page for this app, where the language is chosen:
/// the app's page in iOS Settings, and "App languages" on Android 13 and
/// newer. The real one is [PlatformSystemLanguage]; tests use a fake.
abstract interface class SystemLanguage {
  /// Whether this phone has such a page. Android 12 and older have none, so
  /// the app has its own language picker there.
  Future<bool> isSupported();

  /// Opens the page.
  Future<void> open();
}

class PlatformSystemLanguage implements SystemLanguage {
  const PlatformSystemLanguage();

  static const _channel = MethodChannel('hu.adrian.truenasmobile/language');

  @override
  Future<bool> isSupported() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.android:
        try {
          return await _channel.invokeMethod<bool>('supported') ?? false;
        } on PlatformException {
          return false;
        } on MissingPluginException {
          return false;
        }
      default:
        return false;
    }
  }

  @override
  Future<void> open() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // This app's page in Settings, which lists its languages.
      if (!await launchUrl(Uri.parse('app-settings:'))) {
        throw PlatformException(code: 'failed');
      }
      return;
    }
    await _channel.invokeMethod<void>('open');
  }
}

final systemLanguageProvider = Provider<SystemLanguage>(
  (ref) => const PlatformSystemLanguage(),
);

/// Whether the language is chosen on the phone's own page for the app rather
/// than inside the app. Off here so tests get the in-app picker; `main` asks
/// the phone.
final systemLanguagePageProvider = Provider<bool>((ref) => false);
