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

  @override
  String get tabStorage => 'Storage';

  @override
  String get disksTitle => 'Disks';

  @override
  String get disksSubtitle => 'Health, temperature and pool membership';

  @override
  String get disksEmpty => 'No disks';

  @override
  String get diskUnused => 'Not in a pool';

  @override
  String diskPool(String pool) {
    return 'Pool $pool';
  }

  @override
  String diskSerial(String serial) {
    return 'Serial $serial';
  }

  @override
  String get diskSsd => 'SSD';

  @override
  String diskRpm(int rpm) {
    return '$rpm rpm';
  }

  @override
  String get scrubTitle => 'Scrub';

  @override
  String scrubRunning(String percent) {
    return 'Scrub running: $percent%';
  }

  @override
  String resilverRunning(String percent) {
    return 'Resilver running: $percent%';
  }

  @override
  String scrubPaused(String percent) {
    return 'Scrub paused at $percent%';
  }

  @override
  String scrubFinished(String date, int errors) {
    String _temp0 = intl.Intl.pluralLogic(
      errors,
      locale: localeName,
      other: '$errors errors',
      one: '1 error',
      zero: 'no errors',
    );
    return 'Last scrub finished $date with $_temp0';
  }

  @override
  String get scrubCanceled => 'Last scrub was stopped';

  @override
  String get scrubNever => 'No scrub has run yet';

  @override
  String get scrubStart => 'Start scrub';

  @override
  String get scrubPause => 'Pause';

  @override
  String get scrubResume => 'Resume';

  @override
  String get scrubStop => 'Stop';

  @override
  String get scrubStarted => 'Scrub started';

  @override
  String scrubStopTitle(String pool) {
    return 'Stop the scrub on $pool?';
  }

  @override
  String get scrubStopBody =>
      'Progress is lost and the next scrub starts from the beginning.';

  @override
  String get topologyTitle => 'Layout';

  @override
  String get vdevGroupData => 'Data';

  @override
  String get vdevGroupLog => 'Log';

  @override
  String get vdevGroupCache => 'Cache';

  @override
  String get vdevGroupSpare => 'Spare';

  @override
  String get vdevGroupSpecial => 'Metadata';

  @override
  String get vdevGroupDedup => 'Dedup';

  @override
  String vdevErrors(int read, int write, int checksum) {
    return '$read read, $write write, $checksum checksum errors';
  }

  @override
  String poolFree(String free) {
    return '$free free';
  }

  @override
  String get datasetsTitle => 'Datasets';

  @override
  String get datasetsEmpty => 'No datasets';

  @override
  String get datasetCreate => 'Create dataset';

  @override
  String datasetCreated(String name) {
    return 'Created $name';
  }

  @override
  String get datasetParent => 'Parent';

  @override
  String get datasetNameField => 'Name';

  @override
  String get datasetNameInvalid => 'Use letters, numbers, - _ . and : only';

  @override
  String get datasetTypeFilesystem => 'Dataset';

  @override
  String get datasetTypeVolume => 'Zvol';

  @override
  String get datasetSizeGib => 'Size (GiB)';

  @override
  String get datasetSizeInvalid => 'Enter a size above 0';

  @override
  String get datasetUsed => 'Used';

  @override
  String get datasetAvailable => 'Available';

  @override
  String get datasetCompression => 'Compression';

  @override
  String get datasetCompressRatio => 'Compression ratio';

  @override
  String get datasetMountpoint => 'Mount point';

  @override
  String get datasetVolsize => 'Zvol size';

  @override
  String get datasetEncryption => 'Encryption';

  @override
  String get datasetEncrypted => 'Encrypted';

  @override
  String get datasetLocked => 'Encrypted, locked';

  @override
  String get datasetNotEncrypted => 'Not encrypted';

  @override
  String get datasetZvol => 'Zvol';

  @override
  String get datasetDelete => 'Delete dataset';

  @override
  String datasetDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get datasetDeleteBody =>
      'This permanently destroys the dataset, its child datasets and all their snapshots and data. It cannot be undone.';

  @override
  String typeNameToConfirm(String name) {
    return 'Type $name to confirm';
  }

  @override
  String datasetDeleted(String name) {
    return 'Deleted $name';
  }

  @override
  String get snapshotsTitle => 'Snapshots';

  @override
  String get snapshotsEmpty => 'No snapshots';

  @override
  String get snapshotCreate => 'Create snapshot';

  @override
  String get snapshotNameField => 'Snapshot name';

  @override
  String get snapshotRecursive => 'Include child datasets';

  @override
  String get snapshotCreated => 'Snapshot created';

  @override
  String get snapshotDelete => 'Delete';

  @override
  String snapshotDeleteTitle(String name) {
    return 'Delete snapshot $name?';
  }

  @override
  String get snapshotDeleteBody =>
      'The snapshot is destroyed. Data in the live dataset is not affected.';

  @override
  String get snapshotDeleted => 'Snapshot deleted';

  @override
  String get snapshotRollback => 'Roll back';

  @override
  String snapshotRollbackTitle(String dataset) {
    return 'Roll back $dataset?';
  }

  @override
  String snapshotRollbackBody(String name) {
    return 'The dataset returns to its state at snapshot $name. All changes made since then are lost, and newer snapshots are destroyed.';
  }

  @override
  String snapshotRolledBack(String name) {
    return 'Rolled back to $name';
  }

  @override
  String snapshotSize(String used, String referenced) {
    return '$used used · $referenced referenced';
  }

  @override
  String get create => 'Create';
}
