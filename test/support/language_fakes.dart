import 'package:truenas_mobile/core/settings/system_language.dart';

/// The phone's language page, without a phone.
class FakeSystemLanguage implements SystemLanguage {
  FakeSystemLanguage({this.supported = true, this.failToOpen = false});

  final bool supported;
  final bool failToOpen;

  /// How many times the page was opened.
  int opened = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> open() async {
    if (failToOpen) throw StateError('no settings app');
    opened++;
  }
}
