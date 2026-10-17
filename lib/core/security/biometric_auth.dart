import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// What the phone unlocks with, so the settings text can name it.
enum BiometricKind { face, fingerprint, other }

/// The phone's own way of proving who is holding it: Face ID, a fingerprint,
/// or the device passcode. The real one is [PlatformBiometricAuth]; tests use
/// a fake.
abstract interface class BiometricAuth {
  /// Whether this phone can ask at all: a biometric is enrolled or a passcode
  /// is set. Without either there is nothing to lock the app with.
  Future<bool> isAvailable();

  /// Which biometric the phone has, or [BiometricKind.other] when it only has
  /// a passcode.
  Future<BiometricKind> kind();

  /// Shows the system prompt with [reason]. True once the user passed it,
  /// false when they cancelled or it failed. The device passcode is accepted
  /// as a fallback.
  Future<bool> authenticate(String reason);
}

class PlatformBiometricAuth implements BiometricAuth {
  const PlatformBiometricAuth();

  static final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricKind> kind() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      if (types.contains(BiometricType.fingerprint)) {
        return BiometricKind.fingerprint;
      }
    } catch (_) {
      // Falls through to the generic wording.
    }
    return BiometricKind.other;
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } on LocalAuthException {
      // Cancelled, locked out, or the prompt could not be shown.
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// A phone that cannot lock the app. The default, so tests and platforms
/// without the plugin never see the option; `main` swaps in the real one.
class NoBiometricAuth implements BiometricAuth {
  const NoBiometricAuth();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<BiometricKind> kind() async => BiometricKind.other;

  @override
  Future<bool> authenticate(String reason) async => false;
}

final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => const NoBiometricAuth(),
);

/// Whether the app lock can be offered on this phone.
final biometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricAuthProvider).isAvailable(),
);

final biometricKindProvider = FutureProvider<BiometricKind>(
  (ref) => ref.watch(biometricAuthProvider).kind(),
);
