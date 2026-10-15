// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TrueNAS Mobile';

  @override
  String get serversTitle => 'Servers';

  @override
  String get serversEmptyTitle => 'No servers yet';

  @override
  String get serversEmptyBody =>
      'Add a TrueNAS server (25.04 or newer) to start managing it.';

  @override
  String get addServer => 'Add server';

  @override
  String get editServer => 'Edit server';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Try again';

  @override
  String deleteServerTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteServerBody =>
      'The server is only removed from this app. Nothing changes on the server itself.';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldNameHint => 'Home NAS';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldAddressHint => 'nas.local or https://192.168.1.10';

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldApiKey => 'API key';

  @override
  String get fieldApiKeyHelp =>
      'Create one in TrueNAS under Credentials > Users > API keys.';

  @override
  String get fieldPassword => 'Password';

  @override
  String get authApiKey => 'API key';

  @override
  String get authPassword => 'Password';

  @override
  String get validationRequired => 'Required';

  @override
  String get validationAddress => 'Enter a host name or an http(s) address';

  @override
  String get validationApiKeyHttps =>
      'API keys need HTTPS. TrueNAS revokes keys that are sent over plain HTTP.';

  @override
  String get testConnection => 'Test connection';

  @override
  String testSucceeded(String hostname, String version) {
    return 'Connected to $hostname (TrueNAS $version)';
  }

  @override
  String get connecting => 'Connecting…';

  @override
  String get certificateTitle => 'Trust this certificate?';

  @override
  String get certificateChangedTitle => 'Certificate changed';

  @override
  String get certificateBody =>
      'The server\'s certificate is not signed by an authority this device trusts. This is normal for the self-signed certificate TrueNAS creates. Only trust it if the fingerprint matches the one in TrueNAS under Credentials > Certificates.';

  @override
  String get certificateChangedBody =>
      'The server\'s certificate is different from the one you trusted before. If you did not replace it, someone may be intercepting the connection.';

  @override
  String get certificateSubject => 'Issued to';

  @override
  String get certificateIssuer => 'Issued by';

  @override
  String get certificateExpires => 'Expires';

  @override
  String get certificateFingerprint => 'SHA-256 fingerprint';

  @override
  String get trust => 'Trust';

  @override
  String get otpTitle => 'Two-factor code';

  @override
  String get otpBody => 'Enter the 6-digit code from your authenticator app.';

  @override
  String get otpSubmit => 'Verify';

  @override
  String get errorLoginRejected =>
      'The server rejected the sign-in. Check the username and the API key or password.';

  @override
  String get errorLoginExpired => 'The API key or password has expired.';

  @override
  String get errorUnsupported =>
      'This server is too old. TrueNAS Mobile needs TrueNAS 25.04 or newer.';

  @override
  String get errorCertificate =>
      'The certificate was not trusted, so the app did not connect.';

  @override
  String errorGeneric(String details) {
    return 'Could not connect: $details';
  }

  @override
  String get infoHostname => 'Hostname';

  @override
  String get infoVersion => 'TrueNAS version';

  @override
  String get infoApiVersion => 'API version';

  @override
  String get infoModel => 'CPU';

  @override
  String get infoCores => 'CPU cores';

  @override
  String get infoMemory => 'Memory';

  @override
  String get infoUptime => 'Uptime';

  @override
  String get infoSignedInAs => 'Signed in as';

  @override
  String get errorCancelled => 'Connection cancelled.';

  @override
  String get tabDashboard => 'Dashboard';

  @override
  String get tabAlerts => 'Alerts';

  @override
  String get tabJobs => 'Jobs';

  @override
  String get cpuTitle => 'CPU';

  @override
  String cpuTemperature(String temp) {
    return '$temp °C';
  }

  @override
  String get memoryTitle => 'Memory';

  @override
  String memoryUsedOf(String used, String total) {
    return '$used of $total used';
  }

  @override
  String get memoryServices => 'Services';

  @override
  String get memoryArc => 'ZFS cache';

  @override
  String get memoryFree => 'Free';

  @override
  String get networkTitle => 'Network';

  @override
  String get networkIn => 'In';

  @override
  String get networkOut => 'Out';

  @override
  String get poolsTitle => 'Pools';

  @override
  String get poolsEmpty => 'No pools';

  @override
  String poolUsage(String used, String total) {
    return '$used of $total';
  }

  @override
  String get alertsTitle => 'Alerts';

  @override
  String get alertsNone => 'No active alerts';

  @override
  String alertsCritical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count critical',
      one: '1 critical',
    );
    return '$_temp0';
  }

  @override
  String alertsWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings',
      one: '1 warning',
    );
    return '$_temp0';
  }

  @override
  String alertsInfo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notices',
      one: '1 notice',
    );
    return '$_temp0';
  }

  @override
  String get alertsActive => 'Active';

  @override
  String get alertsDismissed => 'Dismissed';

  @override
  String get alertDismiss => 'Dismiss';

  @override
  String get alertRestore => 'Restore';

  @override
  String get levelCritical => 'Critical';

  @override
  String get levelWarning => 'Warning';

  @override
  String get levelInfo => 'Info';

  @override
  String get jobsEmpty => 'No recent jobs';

  @override
  String get jobAbort => 'Abort';

  @override
  String get jobAbortTitle => 'Abort this job?';

  @override
  String get jobStateWaiting => 'Waiting';

  @override
  String get jobStateRunning => 'Running';

  @override
  String get jobStateSuccess => 'Succeeded';

  @override
  String get jobStateFailed => 'Failed';

  @override
  String get jobStateAborted => 'Aborted';

  @override
  String get close => 'Close';

  @override
  String get liveWaiting => 'Waiting for live data…';

  @override
  String get systemTitle => 'System';
}
