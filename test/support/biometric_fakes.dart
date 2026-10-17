import 'package:truenas_mobile/core/security/biometric_auth.dart';

/// The phone's Face ID / fingerprint prompt, without a phone.
class FakeBiometricAuth implements BiometricAuth {
  FakeBiometricAuth({
    this.available = true,
    this.biometric = BiometricKind.face,
    this.passes = true,
  });

  bool available;
  final BiometricKind biometric;

  /// Whether the next prompts are passed.
  bool passes;

  /// The reasons shown, one per prompt.
  final prompts = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricKind> kind() async => biometric;

  @override
  Future<bool> authenticate(String reason) async {
    prompts.add(reason);
    return passes;
  }
}
