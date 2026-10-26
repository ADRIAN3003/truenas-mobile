import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api/api_exception.dart';
import '../core/api/certificate_trust.dart';
import '../core/api/truenas_connection.dart';
import '../core/session/truenas_session.dart';
import '../core/session/wait_for_server.dart';
import '../l10n/generated/app_localizations.dart';
import 'dialogs.dart';

/// Shows certificate details and returns true when the user trusts it.
Future<bool> confirmCertificateDialog(
  BuildContext context,
  UntrustedCertificate certificate,
) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  Widget row(String label, String value, {bool mono = false}) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        SelectableText(
          value,
          style: mono
              ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
              : theme.textTheme.bodyMedium,
        ),
      ],
    ),
  );

  final trusted = await showAppDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      icon: Icon(
        certificate.changed ? Icons.gpp_bad_outlined : Icons.shield_outlined,
        color: certificate.changed ? theme.colorScheme.error : null,
      ),
      title: Text(
        certificate.changed
            ? l10n.certificateChangedTitle
            : l10n.certificateTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              certificate.changed
                  ? l10n.certificateChangedBody
                  : l10n.certificateBody,
            ),
            row(l10n.certificateSubject, certificate.subject),
            row(l10n.certificateIssuer, certificate.issuer),
            row(
              l10n.certificateExpires,
              DateFormat.yMMMd(locale).format(certificate.validUntil),
            ),
            row(
              l10n.certificateFingerprint,
              certificate.fingerprint,
              mono: true,
            ),
          ],
        ),
      ),
      actions: [
        dialogAction(
          context,
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context, false),
        ),
        dialogAction(
          context,
          label: l10n.trust,
          primary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return trusted ?? false;
}

/// Asks for a two-factor code. Returns null when cancelled.
Future<String?> askOtpDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  return showAppDialog<String>(
    context: context,
    builder: (context) => AppDialog(
      title: Text(l10n.otpTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.otpBody),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            maxLength: 8,
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
      actions: [
        dialogAction(
          context,
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        dialogAction(
          context,
          label: l10n.otpSubmit,
          primary: true,
          onPressed: () => Navigator.pop(context, controller.text),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// A user-facing message for an error thrown while connecting.
String describeConnectError(AppLocalizations l10n, Object error) =>
    switch (error) {
      LoginRejected(reason: 'EXPIRED') => l10n.errorLoginExpired,
      LoginRejected() => l10n.errorLoginRejected,
      UnsupportedServerException() => l10n.errorUnsupported,
      ConnectCancelled() => l10n.errorCancelled,
      ServerWaitTimeout() => l10n.errorWaitTimeout,
      UntrustedCertificateException() => l10n.errorCertificate,
      ApiException(:final message) => l10n.errorGeneric(message),
      _ => l10n.errorGeneric(error.toString()),
    };
