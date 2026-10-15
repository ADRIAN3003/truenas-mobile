import 'dart:io';

import 'package:crypto/crypto.dart';

/// SHA-256 fingerprint of a certificate, as `AB:CD:...` (the format the
/// TrueNAS web UI and browsers show).
String certificateFingerprint(X509Certificate certificate) {
  final digest = sha256.convert(certificate.der);
  return digest.bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}

/// Details of a certificate the system does not trust, shown to the user so
/// they can decide whether to pin it (trust on first use).
class UntrustedCertificate {
  const UntrustedCertificate({
    required this.fingerprint,
    required this.subject,
    required this.issuer,
    required this.validUntil,
    this.pinnedFingerprint,
  });

  factory UntrustedCertificate.from(
    X509Certificate certificate, {
    String? pinnedFingerprint,
  }) => UntrustedCertificate(
    fingerprint: certificateFingerprint(certificate),
    subject: certificate.subject,
    issuer: certificate.issuer,
    validUntil: certificate.endValidity,
    pinnedFingerprint: pinnedFingerprint,
  );

  final String fingerprint;
  final String subject;
  final String issuer;
  final DateTime validUntil;

  /// The previously trusted fingerprint, when the server's certificate changed.
  final String? pinnedFingerprint;

  bool get changed => pinnedFingerprint != null;
}

/// Thrown when the server presents a certificate that is neither trusted by
/// the system nor pinned for this server.
class UntrustedCertificateException implements Exception {
  const UntrustedCertificateException(this.certificate);

  final UntrustedCertificate certificate;

  @override
  String toString() =>
      'UntrustedCertificateException(${certificate.fingerprint})';
}

/// Builds an [HttpClient] that accepts system-trusted certificates plus the
/// one certificate pinned for this server, and remembers any other
/// certificate it rejected so the caller can offer to trust it.
class PinningHttpClientFactory {
  PinningHttpClientFactory({this.pinnedFingerprint});

  final String? pinnedFingerprint;
  X509Certificate? rejected;

  HttpClient create() {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    client.badCertificateCallback = (certificate, host, port) {
      if (pinnedFingerprint != null &&
          certificateFingerprint(certificate) == pinnedFingerprint) {
        return true;
      }
      rejected = certificate;
      return false;
    };
    return client;
  }

  UntrustedCertificateException? get rejection {
    final certificate = rejected;
    if (certificate == null) return null;
    return UntrustedCertificateException(
      UntrustedCertificate.from(
        certificate,
        pinnedFingerprint: pinnedFingerprint,
      ),
    );
  }
}
