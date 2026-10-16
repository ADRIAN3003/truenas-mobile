import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/settings/system_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hu.adrian.truenasmobile/language');
  final calls = <String>[];

  void mock(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return handler(call);
        });
  }

  setUp(calls.clear);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Android 13 and newer have a page; older ones ask the app', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mock((_) => true);
    expect(await const PlatformSystemLanguage().isSupported(), isTrue);
    mock((_) => false);
    expect(await const PlatformSystemLanguage().isSupported(), isFalse);
  });

  test('Android without the native side has no page', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await const PlatformSystemLanguage().isSupported(), isFalse);
    mock((_) => throw PlatformException(code: 'failed'));
    expect(await const PlatformSystemLanguage().isSupported(), isFalse);
  });

  test('iOS always has the app page in Settings; other systems none', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await const PlatformSystemLanguage().isSupported(), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(await const PlatformSystemLanguage().isSupported(), isFalse);
    expect(calls, isEmpty);
  });

  test('on Android, opening asks the native side', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mock((_) => null);
    await const PlatformSystemLanguage().open();
    expect(calls, ['open']);
  });
}
