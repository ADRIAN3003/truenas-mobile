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
  String get tabDashboard => 'Home';

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
    return 'The dataset returns to its state at snapshot $name. Everything changed since then is lost.';
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

  @override
  String get tabShares => 'Shares';

  @override
  String get servicesTitle => 'Services';

  @override
  String get servicesSubtitle => 'Start, stop, and choose what starts on boot';

  @override
  String get servicesEmpty => 'No services';

  @override
  String get serviceRunning => 'Running';

  @override
  String get serviceStopped => 'Stopped';

  @override
  String get serviceStart => 'Start';

  @override
  String get serviceStop => 'Stop';

  @override
  String get serviceRestart => 'Restart';

  @override
  String get serviceStartOnBoot => 'Start on boot';

  @override
  String serviceStopTitle(String name) {
    return 'Stop $name?';
  }

  @override
  String get serviceStopBody =>
      'Clients using this service lose access until it is started again.';

  @override
  String serviceStartedMessage(String name) {
    return '$name is running';
  }

  @override
  String serviceStoppedMessage(String name) {
    return '$name stopped';
  }

  @override
  String serviceNotRunning(String name) {
    return 'The $name service is stopped, so these shares can\'t be reached.';
  }

  @override
  String get smbTitle => 'SMB shares';

  @override
  String get nfsTitle => 'NFS shares';

  @override
  String sharesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shares',
      one: '1 share',
      zero: 'No shares',
    );
    return '$_temp0';
  }

  @override
  String get sharesEmpty => 'No shares yet';

  @override
  String get shareCreate => 'Add share';

  @override
  String get shareEdit => 'Edit share';

  @override
  String get shareName => 'Share name';

  @override
  String get sharePath => 'Folder';

  @override
  String get shareComment => 'Description';

  @override
  String get shareReadOnly => 'Read only';

  @override
  String get shareBrowsable => 'Visible when browsing the network';

  @override
  String get shareEnabled => 'Enabled';

  @override
  String get shareDisabled => 'Disabled';

  @override
  String get shareLocked => 'Dataset locked';

  @override
  String get shareNoDatasets =>
      'Create a dataset first. A share always points at a dataset\'s folder.';

  @override
  String get shareCreated => 'Share added';

  @override
  String get shareSaved => 'Share saved';

  @override
  String get shareDelete => 'Delete share';

  @override
  String shareDeleteTitle(String name) {
    return 'Delete share $name?';
  }

  @override
  String shareDeleteBody(String path) {
    return 'Clients can no longer reach it. The files in $path are kept.';
  }

  @override
  String get shareDeleted => 'Share deleted';

  @override
  String get nfsAllowedEveryone => 'Any host can connect';

  @override
  String nfsAllowed(String list) {
    return 'Allowed: $list';
  }

  @override
  String get iscsiTitle => 'iSCSI';

  @override
  String get iscsiTargets => 'Targets';

  @override
  String get iscsiExtents => 'Extents';

  @override
  String iscsiSummary(int targets, int extents) {
    return 'Targets: $targets · Extents: $extents';
  }

  @override
  String get iscsiEmpty => 'No iSCSI targets';

  @override
  String get nvmetTitle => 'NVMe over Fabrics';

  @override
  String nvmetSummary(int count) {
    return 'Subsystems: $count';
  }

  @override
  String get nvmetEmpty => 'No NVMe-oF subsystems';

  @override
  String get nvmetAnyHost => 'Any host can connect';

  @override
  String get nvmetAllowedHosts => 'Only allowed hosts can connect';

  @override
  String get viewOnlyNote =>
      'View only for now. Use the TrueNAS web interface to change these.';

  @override
  String get tabApps => 'Apps';

  @override
  String get tabMore => 'More';

  @override
  String get appsTitle => 'Apps';

  @override
  String get appsEmpty => 'No apps installed';

  @override
  String get vmsTitle => 'Virtual machines';

  @override
  String get vmsEmpty => 'No virtual machines';

  @override
  String get containersTitle => 'Containers';

  @override
  String get containersEmpty => 'No containers';

  @override
  String get stateRunning => 'Running';

  @override
  String get stateStopped => 'Stopped';

  @override
  String get stateDeploying => 'Starting';

  @override
  String get stateStopping => 'Stopping';

  @override
  String get stateSuspended => 'Paused';

  @override
  String get stateCrashed => 'Crashed';

  @override
  String get stateUnknown => 'Unknown';

  @override
  String get actionStart => 'Start';

  @override
  String get actionStop => 'Stop';

  @override
  String get actionRestart => 'Restart';

  @override
  String get actionPowerOff => 'Power off';

  @override
  String get actionUpgrade => 'Upgrade';

  @override
  String get actionDelete => 'Delete';

  @override
  String actionStarted(String name) {
    return '$name started';
  }

  @override
  String actionStopped(String name) {
    return '$name stopped';
  }

  @override
  String actionRestarted(String name) {
    return '$name restarted';
  }

  @override
  String actionPoweredOff(String name) {
    return '$name powered off';
  }

  @override
  String actionUpgraded(String name) {
    return '$name upgraded';
  }

  @override
  String actionDeleted(String name) {
    return '$name deleted';
  }

  @override
  String stopTitle(String name) {
    return 'Stop $name?';
  }

  @override
  String get stopBody => 'It can\'t be reached until it is started again.';

  @override
  String get vmStopBody =>
      'The guest is asked to shut down. If it hasn\'t within its shutdown timeout, it is powered off.';

  @override
  String restartTitle(String name) {
    return 'Restart $name?';
  }

  @override
  String get restartBody => 'It is unavailable for a moment while it restarts.';

  @override
  String vmPowerOffTitle(String name) {
    return 'Power off $name?';
  }

  @override
  String get vmPowerOffBody =>
      'This cuts power immediately, like pulling the plug. Unsaved work inside the VM can be lost.';

  @override
  String appUpgradeTitle(String name) {
    return 'Upgrade $name?';
  }

  @override
  String appUpgradeBody(String name, String from, String to) {
    return '$name goes from $from to $to. The app restarts during the upgrade.';
  }

  @override
  String appDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get appDeleteBody =>
      'The app and its containers and images are removed. Data in its volumes and host folders is kept.';

  @override
  String get appUpdateAvailable => 'Update available';

  @override
  String get appImageUpdates => 'Newer images available';

  @override
  String get appVersion => 'Version';

  @override
  String get appLatestVersion => 'Latest version';

  @override
  String get appContainersRunning => 'Running containers';

  @override
  String get appImages => 'Images';

  @override
  String get appPortals => 'Web interfaces';

  @override
  String get appCustom => 'Custom app';

  @override
  String get appNotes => 'Notes';

  @override
  String vmSummary(int vcpus, String memory) {
    return '$vcpus vCPU · $memory';
  }

  @override
  String get vmAutostart => 'Starts on boot';

  @override
  String get containerIsVm => 'Incus VM';

  @override
  String get copied => 'Copied';

  @override
  String get moreAccounts => 'Accounts';

  @override
  String get moreSystem => 'System';

  @override
  String get moreActivity => 'Activity';

  @override
  String get usersTitle => 'Users';

  @override
  String get usersEmpty => 'No users yet. System accounts are hidden.';

  @override
  String get usersShowBuiltin => 'Show system accounts';

  @override
  String get userCreate => 'Add user';

  @override
  String get userUsername => 'Username';

  @override
  String get userFullName => 'Full name';

  @override
  String get userPassword => 'Password';

  @override
  String get userSmb => 'Allow SMB access';

  @override
  String get userUsernameInvalid =>
      'Use lowercase letters, digits, - or _, starting with a letter';

  @override
  String get userPasswordRequired => 'Enter a password';

  @override
  String userCreated(String name) {
    return 'Added $name';
  }

  @override
  String get userLocked => 'Locked';

  @override
  String get userBuiltin => 'System';

  @override
  String get userLock => 'Lock';

  @override
  String get userUnlock => 'Unlock';

  @override
  String userLockedMessage(String name) {
    return 'Locked $name';
  }

  @override
  String userUnlockedMessage(String name) {
    return 'Unlocked $name';
  }

  @override
  String userDeleteTitle(String name) {
    return 'Delete user $name?';
  }

  @override
  String get userDeleteBody =>
      'The account and its private group are removed. Files it owns stay on disk.';

  @override
  String userDeleted(String name) {
    return 'Deleted $name';
  }

  @override
  String get userTwoFactor => 'Two-factor';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get groupsEmpty => 'No groups yet. System groups are hidden.';

  @override
  String get groupCreate => 'Add group';

  @override
  String get groupName => 'Group name';

  @override
  String groupCreated(String name) {
    return 'Added $name';
  }

  @override
  String groupDeleteTitle(String name) {
    return 'Delete group $name?';
  }

  @override
  String get groupDeleteBody => 'Members keep their accounts.';

  @override
  String groupDeleted(String name) {
    return 'Deleted $name';
  }

  @override
  String get apiKeysTitle => 'API keys';

  @override
  String get apiKeysEmpty => 'No API keys yet.';

  @override
  String get apiKeyCreate => 'Add API key';

  @override
  String get apiKeyName => 'Key name';

  @override
  String get apiKeyUser => 'For user';

  @override
  String get apiKeyCreatedTitle => 'Copy your API key';

  @override
  String get apiKeyCreatedBody =>
      'This is the only time the key is shown. Store it somewhere safe.';

  @override
  String get apiKeyCopied => 'Copied to clipboard';

  @override
  String get apiKeyRevoked => 'Revoked';

  @override
  String apiKeyExpires(String date) {
    return 'Expires $date';
  }

  @override
  String apiKeyCreatedOn(String date) {
    return 'Created $date';
  }

  @override
  String apiKeyDeleteTitle(String name) {
    return 'Delete API key $name?';
  }

  @override
  String get apiKeyDeleteBody => 'Anything using this key loses access.';

  @override
  String apiKeyDeleted(String name) {
    return 'Deleted $name';
  }

  @override
  String get copy => 'Copy';

  @override
  String get done => 'Done';

  @override
  String get networkHostname => 'Hostname';

  @override
  String get networkGateway => 'Default gateway';

  @override
  String get networkDns => 'DNS servers';

  @override
  String get networkInterfaces => 'Interfaces';

  @override
  String get networkLinkUp => 'Link up';

  @override
  String get networkLinkDown => 'Link down';

  @override
  String get networkDhcp => 'DHCP';

  @override
  String get networkNone => 'None';

  @override
  String get certificatesTitle => 'Certificates';

  @override
  String get certificatesEmpty => 'No certificates.';

  @override
  String get certificateExpired => 'Expired';

  @override
  String certificateValidUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String get updatesTitle => 'Updates';

  @override
  String updateCurrent(String version) {
    return 'Running $version';
  }

  @override
  String updateAvailable(String version) {
    return '$version is available';
  }

  @override
  String get updateNone => 'TrueNAS is up to date';

  @override
  String get updateRebootRequired =>
      'An update is installed. Restart to finish.';

  @override
  String updateCheckFailed(String reason) {
    return 'Couldn\'t check for updates: $reason';
  }

  @override
  String get updateInstall => 'Install and restart';

  @override
  String updateInstallTitle(String version) {
    return 'Install $version?';
  }

  @override
  String get updateInstallBody =>
      'The server downloads the update, installs it and restarts. It is unavailable while it restarts.';

  @override
  String get updateStarted =>
      'Update started. The server restarts when it\'s done.';

  @override
  String get updateReleaseNotes => 'Release notes';

  @override
  String get bootEnvsTitle => 'Boot environments';

  @override
  String get bootEnvActive => 'Running now';

  @override
  String get bootEnvNextBoot => 'Used on next boot';

  @override
  String get bootEnvKept => 'Kept';

  @override
  String get bootEnvActivate => 'Use on next boot';

  @override
  String bootEnvActivateTitle(String name) {
    return 'Boot $name next time?';
  }

  @override
  String get bootEnvActivateBody =>
      'The server uses this version after its next restart.';

  @override
  String get bootEnvKeep => 'Keep';

  @override
  String get bootEnvUnkeep => 'Stop keeping';

  @override
  String bootEnvDeleteTitle(String name) {
    return 'Delete boot environment $name?';
  }

  @override
  String get bootEnvDeleteBody =>
      'You can\'t go back to this version afterwards.';

  @override
  String get bootEnvChanged => 'Boot environment updated';

  @override
  String get powerReboot => 'Restart server';

  @override
  String get powerShutdown => 'Shut down server';

  @override
  String powerRebootTitle(String name) {
    return 'Restart $name?';
  }

  @override
  String powerShutdownTitle(String name) {
    return 'Shut down $name?';
  }

  @override
  String get powerRebootBody =>
      'Everything on the server, including shares, apps and VMs, stops until it is back.';

  @override
  String get powerShutdownBody =>
      'Everything on the server stops. You need physical or remote console access to turn it back on.';

  @override
  String powerRebooting(String name) {
    return '$name is restarting';
  }

  @override
  String powerShuttingDown(String name) {
    return '$name is shutting down';
  }

  @override
  String get restart => 'Restart';

  @override
  String get shutDown => 'Shut down';

  @override
  String groupMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String get moreTools => 'Tools';

  @override
  String get explorerTitle => 'API explorer';

  @override
  String get explorerSearch => 'Search methods';

  @override
  String get explorerNoMatches => 'No methods match.';

  @override
  String explorerMethodCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count methods',
      one: '1 method',
    );
    return '$_temp0';
  }

  @override
  String get explorerJob => 'Job';

  @override
  String get explorerReadOnly => 'Read-only';

  @override
  String get explorerNoAuth => 'No sign-in needed';

  @override
  String explorerRoles(String roles) {
    return 'Roles: $roles';
  }

  @override
  String get explorerParameters => 'Parameters';

  @override
  String get explorerNoParameters => 'This method takes no parameters.';

  @override
  String get explorerSendParam => 'Send';

  @override
  String get explorerOptional => 'optional';

  @override
  String explorerInvalidJson(String reason) {
    return 'Not valid JSON: $reason';
  }

  @override
  String get explorerInvalidNumber => 'Enter a number';

  @override
  String get explorerRun => 'Run';

  @override
  String explorerRunTitle(String method) {
    return 'Run $method?';
  }

  @override
  String get explorerRunBody =>
      'This method can change settings or data on the server.';

  @override
  String get explorerResult => 'Result';

  @override
  String explorerJobRunning(int id) {
    return 'Running as job $id…';
  }

  @override
  String get explorerReturns => 'Returns';

  @override
  String get explorerFileTransfer =>
      'This method transfers a file, which the explorer can\'t do yet.';

  @override
  String get explorerCopied => 'Copied to clipboard';

  @override
  String get explorerUnset => 'Not set';

  @override
  String get shellTitle => 'Shell';

  @override
  String get shellConnecting => 'Opening a shell…';

  @override
  String get shellClosed => 'The shell has ended.';

  @override
  String get shellReconnect => 'Start a new shell';

  @override
  String get shellKeyCtrlC => 'Ctrl+C';

  @override
  String get shellKeyEsc => 'Esc';

  @override
  String get shellKeyTab => 'Tab';

  @override
  String get protectionTitle => 'Data protection';

  @override
  String get protectionEmpty => 'No tasks yet.';

  @override
  String get protectionSnapshots => 'Periodic snapshots';

  @override
  String get protectionReplication => 'Replication';

  @override
  String get protectionCloudSync => 'Cloud sync';

  @override
  String get protectionCloudBackup => 'TrueCloud backup';

  @override
  String get protectionRsync => 'Rsync';

  @override
  String get taskNever => 'Not run yet';

  @override
  String get taskWaiting => 'Waiting';

  @override
  String get taskRunning => 'Running';

  @override
  String taskRunningPercent(int percent) {
    return 'Running · $percent%';
  }

  @override
  String get taskSuccess => 'Succeeded';

  @override
  String get taskFailed => 'Failed';

  @override
  String get taskHeld => 'On hold';

  @override
  String taskLastRun(String date) {
    return 'Last run $date';
  }

  @override
  String get taskEnabled => 'Enabled';

  @override
  String get taskRunNow => 'Run now';

  @override
  String get taskStop => 'Stop';

  @override
  String taskStarted(String name) {
    return 'Started $name';
  }

  @override
  String taskStopped(String name) {
    return 'Stopped $name';
  }

  @override
  String taskEnabledMessage(String name) {
    return 'Enabled $name';
  }

  @override
  String taskDisabledMessage(String name) {
    return 'Disabled $name';
  }

  @override
  String taskDeleteTitle(String name) {
    return 'Delete the task for $name?';
  }

  @override
  String get taskDeleteBody => 'Snapshots it already took are kept.';

  @override
  String get taskDeleted => 'Task deleted';

  @override
  String get snapshotTaskCreate => 'Add snapshot task';

  @override
  String snapshotTaskCreated(String name) {
    return 'Added a snapshot task for $name';
  }

  @override
  String get snapshotTaskDataset => 'Dataset';

  @override
  String get snapshotTaskRecursive => 'Include child datasets';

  @override
  String get snapshotTaskSchedule => 'How often';

  @override
  String get snapshotTaskKeepFor => 'Keep for';

  @override
  String get scheduleHourly => 'Every hour';

  @override
  String get scheduleDaily => 'Every day at midnight';

  @override
  String get scheduleWeekly => 'Every Sunday at midnight';

  @override
  String scheduleCustom(String cron) {
    return 'Cron: $cron';
  }

  @override
  String get snapshotTaskRecursiveLabel => 'with child datasets';

  @override
  String keepHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keep $count hours',
      one: 'Keep 1 hour',
    );
    return '$_temp0';
  }

  @override
  String keepDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keep $count days',
      one: 'Keep 1 day',
    );
    return '$_temp0';
  }

  @override
  String keepWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keep $count weeks',
      one: 'Keep 1 week',
    );
    return '$_temp0';
  }

  @override
  String keepMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keep $count months',
      one: 'Keep 1 month',
    );
    return '$_temp0';
  }

  @override
  String keepYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keep $count years',
      one: 'Keep 1 year',
    );
    return '$_temp0';
  }

  @override
  String get unitHours => 'Hours';

  @override
  String get unitDays => 'Days';

  @override
  String get unitWeeks => 'Weeks';

  @override
  String get unitMonths => 'Months';

  @override
  String get unitYears => 'Years';

  @override
  String get protectionSubtitle => 'Snapshot tasks, replication and cloud sync';

  @override
  String get protectionAdd => 'Add task';

  @override
  String get taskDeleteBodyCopies => 'Data it already copied is kept.';

  @override
  String taskSaved(String name) {
    return 'Saved $name';
  }

  @override
  String get replicationNew => 'New replication task';

  @override
  String get replicationEdit => 'Edit replication task';

  @override
  String get cloudSyncNew => 'New cloud sync task';

  @override
  String get cloudSyncEdit => 'Edit cloud sync task';

  @override
  String get taskNameLabel => 'Name';

  @override
  String get directionLabel => 'Direction';

  @override
  String get replicationPush => 'Push: send from this server';

  @override
  String get replicationPull => 'Pull: fetch from another server';

  @override
  String get replicationTransport => 'Destination';

  @override
  String get transportLocal => 'Another pool on this server';

  @override
  String get transportSsh => 'Another server over SSH';

  @override
  String get transportNetcat => 'Another server over SSH with netcat';

  @override
  String get replicationSshConnection => 'SSH connection';

  @override
  String get replicationNoSshConnections =>
      'No SSH connections yet. Add one under Credentials in the TrueNAS web interface.';

  @override
  String get replicationSources => 'Source datasets';

  @override
  String get replicationSourcesHint => 'Separate several with commas';

  @override
  String get replicationTarget => 'Destination dataset';

  @override
  String get pickDataset => 'Choose a dataset';

  @override
  String get replicationSnapshotTasks => 'Send snapshots taken by';

  @override
  String get replicationNoSnapshotTasks =>
      'No periodic snapshot tasks. Snapshots are matched by name instead.';

  @override
  String get replicationNamingSchema => 'Snapshot name pattern';

  @override
  String get replicationNamingSchemaHint => 'For example auto-%Y-%m-%d_%H-%M';

  @override
  String replicationNameRegex(String regex) {
    return 'Snapshots are matched by the pattern $regex. Change it in the TrueNAS web interface.';
  }

  @override
  String get replicationAuto => 'Run automatically';

  @override
  String get replicationAfterSnapshots => 'Right after the snapshot task';

  @override
  String get replicationRetention => 'Keep snapshots on the destination';

  @override
  String get retentionSource => 'Same as the source';

  @override
  String get retentionCustom => 'For a set time';

  @override
  String get retentionNone => 'Forever';

  @override
  String get cloudSyncDescription => 'Description';

  @override
  String get cloudSyncCredential => 'Cloud credential';

  @override
  String get cloudSyncNoCredentials =>
      'No cloud credentials yet. Add one under Credentials in the TrueNAS web interface.';

  @override
  String get cloudSyncBucket => 'Bucket';

  @override
  String get cloudSyncBucketHint => 'Leave empty for providers without buckets';

  @override
  String get cloudSyncFolder => 'Remote folder';

  @override
  String get cloudSyncPath => 'Local folder';

  @override
  String get cloudSyncPathHint => 'A folder under /mnt';

  @override
  String get cloudSyncPathInvalid => 'Choose a folder under /mnt';

  @override
  String get cloudSyncPush => 'Push: upload to the cloud';

  @override
  String get cloudSyncPull => 'Pull: download from the cloud';

  @override
  String get transferModeLabel => 'Transfer mode';

  @override
  String get transferCopy => 'Copy new and changed files';

  @override
  String get transferSync => 'Mirror, deleting files missing at the source';

  @override
  String get transferMove => 'Move, deleting files from the source';

  @override
  String get showSecret => 'Show';

  @override
  String get hideSecret => 'Hide';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get shellKeyUp => 'Arrow up';

  @override
  String get shellKeyDown => 'Arrow down';

  @override
  String get shellKeyLeft => 'Arrow left';

  @override
  String get shellKeyRight => 'Arrow right';

  @override
  String get shellNoContainers =>
      'This app has no running containers to open a shell in.';

  @override
  String get shellPickContainer => 'Open a shell in';

  @override
  String get rsyncNew => 'New rsync task';

  @override
  String get rsyncEdit => 'Edit rsync task';

  @override
  String get rsyncUser => 'Run as user';

  @override
  String get rsyncUserHint =>
      'A local user; over SSH without a saved connection, it needs its own SSH key';

  @override
  String get rsyncPush => 'Push: copy to the remote host';

  @override
  String get rsyncPull => 'Pull: copy from the remote host';

  @override
  String get rsyncMode => 'Connect with';

  @override
  String get rsyncModeSsh => 'SSH';

  @override
  String get rsyncModeModule => 'Rsync daemon module';

  @override
  String get rsyncManualHost => 'Enter a host instead';

  @override
  String get rsyncHost => 'Remote host';

  @override
  String get rsyncPort => 'SSH port';

  @override
  String get rsyncModule => 'Module name';

  @override
  String get rsyncRemotePath => 'Remote path';

  @override
  String get rsyncDelete => 'Delete files missing at the source';

  @override
  String get cloudBackupNew => 'New TrueCloud backup task';

  @override
  String get cloudBackupEdit => 'Edit TrueCloud backup task';

  @override
  String get cloudBackupPassword => 'Repository password';

  @override
  String get cloudBackupPasswordHint =>
      'Encrypts the backups. Keep it safe: without it they can\'t be restored.';

  @override
  String get cloudBackupPasswordKeep =>
      'Leave empty to keep the current password';

  @override
  String get cloudBackupKeepLast => 'Backups to keep';

  @override
  String get dashboardConnected => 'Connected';

  @override
  String get fieldPasswordKeep =>
      'Leave empty to keep the saved password, or type a new one to replace it.';

  @override
  String get fieldApiKeyKeep =>
      'Leave empty to keep the saved API key, or paste a new one to replace it.';

  @override
  String get tabSharesShort => 'Shares';

  @override
  String shellFallback(String shell) {
    return 'That shell is not in this container. Trying $shell instead.';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '1 server',
    );
    return '$_temp0';
  }

  @override
  String get shellPaste => 'Paste';

  @override
  String get shellCopied => 'Copied to clipboard';

  @override
  String leaveServerTitle(String name) {
    return 'Disconnect from $name?';
  }

  @override
  String get leaveServerBody =>
      'You will return to your servers and this connection will be closed, along with any shell or other screen open on it.';

  @override
  String get leaveServerConfirm => 'Disconnect';

  @override
  String get leaveServerStay => 'Stay';

  @override
  String get settingsTitle => 'App settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsSystemDefault => 'Same as device';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsHapticsHint =>
      'Small taps when you refresh, switch tabs or confirm';

  @override
  String get settingsConfirmLeave => 'Ask before closing';

  @override
  String get settingsConfirmLeaveHint =>
      'Confirm before leaving an open server or shell';

  @override
  String get settingsShell => 'Shell';

  @override
  String get settingsShellFontSize => 'Font size';

  @override
  String get settingsShellKeys => 'Extra keys';

  @override
  String get settingsShellKeysHint =>
      'Esc, Tab, Ctrl+C and arrows under the terminal';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsAlertNotifications => 'Alert notifications';

  @override
  String get settingsAlertNotificationsHintIos =>
      'Checks your servers in the background and notifies you of new alerts. iOS decides when the check runs, so it can be late, and it stops if you swipe the app away.';

  @override
  String get settingsAlertNotificationsHintAndroid =>
      'Checks your servers in the background about every 15 minutes and notifies you of new alerts.';

  @override
  String get settingsAlertKinds => 'Alert types';

  @override
  String settingsAlertKindsMuted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count off',
      zero: 'All on',
    );
    return '$_temp0';
  }

  @override
  String get alertKindsTitle => 'Alert types';

  @override
  String get alertKindsHint =>
      'Switch off the types of alert you don\'t want a notification for. They still show in the Alerts list.';

  @override
  String get alertKindsEmpty =>
      'Alert types appear here after the first background check of a server.';

  @override
  String get alertKindsSearch => 'Search';

  @override
  String get alertKindsOther => 'Other';

  @override
  String get alertMuteKind => 'Don\'t notify for this type';

  @override
  String get alertUnmuteKind => 'Notify for this type again';

  @override
  String alertKindMuted(String kind) {
    return 'No more notifications for \"$kind\"';
  }

  @override
  String alertKindUnmuted(String kind) {
    return 'Notifications for \"$kind\" are back';
  }

  @override
  String get settingsAlertLevel => 'Notify for';

  @override
  String get settingsAlertLevelCritical => 'Critical alerts';

  @override
  String get settingsAlertLevelWarning => 'Warnings and critical';

  @override
  String get settingsAlertPermissionDenied =>
      'Notifications are turned off for this app. Allow them in the phone\'s settings first.';

  @override
  String get settingsAlertScheduleFailed =>
      'The phone would not start the background check. Try again in a moment.';

  @override
  String get alertNotificationChannel => 'Alerts';

  @override
  String get alertNotificationChannelDescription =>
      'New alerts from your TrueNAS servers';

  @override
  String alertNotificationMany(int count) {
    return '$count new alerts';
  }

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsAppLock => 'App lock';

  @override
  String get settingsAppLockHintFace =>
      'Ask for Face ID or the device passcode when the app opens or comes back from the background.';

  @override
  String get settingsAppLockHintFingerprint =>
      'Ask for a fingerprint or the device passcode when the app opens or comes back from the background.';

  @override
  String get settingsAppLockHintOther =>
      'Ask for biometrics or the device passcode when the app opens or comes back from the background.';

  @override
  String get appLockReason => 'Unlock TrueNAS Mobile';

  @override
  String get appLockChangeReason => 'Confirm it\'s you to change the app lock';

  @override
  String get appLockTitle => 'TrueNAS Mobile is locked';

  @override
  String get appLockFailed => 'Not unlocked. Try again.';

  @override
  String get appLockUnlock => 'Unlock';

  @override
  String get settingsCertificates => 'Trusted certificates';

  @override
  String get settingsCertificatesEmpty =>
      'No certificates are trusted. A self-signed certificate you accept for a server will show up here.';

  @override
  String get settingsCertificateForget => 'Forget';

  @override
  String settingsCertificateForgetTitle(String name) {
    return 'Forget the certificate of $name?';
  }

  @override
  String get settingsCertificateForgetBody =>
      'You will be asked whether to trust it again the next time you connect.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsLicences => 'Open-source licences';

  @override
  String get settingsSource => 'Source code';

  @override
  String get shellLeaveTitle => 'Close the shell?';

  @override
  String get shellLeaveBody => 'Anything running in it stops.';

  @override
  String get shellLeaveConfirm => 'Close shell';

  @override
  String get settingsUpdates => 'Updates';

  @override
  String get settingsCheckUpdates => 'Check on start';

  @override
  String get settingsCheckUpdatesHint =>
      'Looks for a newer release on GitHub when the app opens. Nothing else is sent.';

  @override
  String get settingsCheckNow => 'Check for updates';

  @override
  String get settingsReleaseNotes => 'Release notes';

  @override
  String get appUpdateTitle => 'Software update';

  @override
  String get appUpdateChecking => 'Checking for updates…';

  @override
  String get appUpdateUpToDateTitle => 'You\'re up to date';

  @override
  String appUpdateUpToDateBody(String version) {
    return 'TrueNAS Mobile $version is the newest release.';
  }

  @override
  String get appUpdateNoReleases => 'No releases have been published yet.';

  @override
  String appUpdateAvailableTitle(String version) {
    return 'Version $version is available';
  }

  @override
  String appUpdateAvailableBody(String current) {
    return 'You have version $current.';
  }

  @override
  String appUpdateReleased(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Released $dateString';
  }

  @override
  String get appUpdateDownload => 'Download and install';

  @override
  String get appUpdateOpenRelease => 'Open release page';

  @override
  String get appUpdateViewOnGitHub => 'View on GitHub';

  @override
  String get appUpdateSkip => 'Skip this version';

  @override
  String get appUpdateSkippedNote =>
      'You chose to skip this version, so it is not offered when the app opens.';

  @override
  String get appUpdateUnskip => 'Stop skipping';

  @override
  String get appUpdateLater => 'Later';

  @override
  String get appUpdateViewUpdate => 'View update';

  @override
  String get appUpdatePromptTitle => 'Update available';

  @override
  String appUpdatePromptBody(String version, String current) {
    return 'Version $version is available. You have $current.';
  }

  @override
  String get appUpdateDownloading => 'Downloading…';

  @override
  String appUpdateDownloadingPercent(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get appUpdateInstalling => 'Opening the installer…';

  @override
  String get appUpdateWhatsNew => 'What\'s new';

  @override
  String get appUpdateNoNotes => 'This release has no notes.';

  @override
  String get appUpdateAllNotes => 'All release notes';

  @override
  String get appUpdateCheckFailed =>
      'Couldn\'t check for updates. Check your connection and try again.';

  @override
  String get appUpdateRateLimited =>
      'GitHub is limiting requests from this network. Try again later.';

  @override
  String get appUpdateErrNoApk =>
      'This release has no APK for your phone. Open the release page to get it.';

  @override
  String get appUpdateErrDownload =>
      'The download failed. Check your connection and try again.';

  @override
  String get appUpdateErrDamaged =>
      'The downloaded file is damaged. Try again.';

  @override
  String get appUpdateErrInstall => 'Couldn\'t open the installer.';

  @override
  String get appUpdatePermissionTitle => 'Allow installing updates';

  @override
  String get appUpdatePermissionBody =>
      'Android asks for your permission before an app can install updates. Open the settings, allow it for TrueNAS Mobile, then come back and tap Download and install again.';

  @override
  String get appUpdateOpenSettings => 'Open settings';

  @override
  String appsUpdatesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps have updates',
      one: '1 app has an update',
    );
    return '$_temp0';
  }

  @override
  String get appsUpdateAll => 'Update all';

  @override
  String appsUpdateAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Update $count apps?',
      one: 'Update 1 app?',
    );
    return '$_temp0';
  }

  @override
  String get appsUpdateAllBody =>
      'TrueNAS updates these apps itself, one after another, and each restarts while it updates. It carries on if you close the app.';

  @override
  String get appsUpdateAllLeave =>
      'TrueNAS carries on if you leave this screen or close the app.';

  @override
  String appsBulkRunning(String action, int done, int total) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'upgrade': 'Updating',
      'start': 'Starting',
      'stop': 'Stopping',
      'restart': 'Restarting',
      'other': 'Working',
    });
    return '$_temp0 on the server: $done of $total done';
  }

  @override
  String appsBulkRunningNoCount(String action, int total) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'upgrade': 'Updating',
      'start': 'Starting',
      'stop': 'Stopping',
      'restart': 'Restarting',
      'other': 'Working',
    });
    String _temp1 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total apps',
      one: '1 app',
    );
    return '$_temp0 $_temp1 on the server';
  }

  @override
  String appsBulkDone(int count, String action) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps',
      one: '1 app',
    );
    String _temp1 = intl.Intl.selectLogic(action, {
      'upgrade': 'updated',
      'start': 'started',
      'stop': 'stopped',
      'restart': 'restarted',
      'other': 'done',
    });
    return '$_temp0 $_temp1';
  }

  @override
  String appsBulkPartial(int done, int total, String failed, String action) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'upgrade': 'updated',
      'start': 'started',
      'stop': 'stopped',
      'restart': 'restarted',
      'other': 'done',
    });
    String _temp1 = intl.Intl.selectLogic(action, {
      'upgrade': 'Not updated',
      'start': 'Not started',
      'stop': 'Not stopped',
      'restart': 'Not restarted',
      'other': 'Failed',
    });
    return '$done of $total apps $_temp0. $_temp1: $failed';
  }

  @override
  String get appsSelect => 'Select';

  @override
  String get appsSelectAll => 'Select all';

  @override
  String appsSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get appsBulkUpdate => 'Update';

  @override
  String appsBulkStopTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Stop $count apps?',
      one: 'Stop 1 app?',
    );
    return '$_temp0';
  }

  @override
  String get appsBulkStopBody =>
      'They can\'t be reached until they are started again.';

  @override
  String appsBulkRestartTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restart $count apps?',
      one: 'Restart 1 app?',
    );
    return '$_temp0';
  }

  @override
  String get appsBulkRestartBody =>
      'They are unavailable for a moment while they restart.';

  @override
  String get settingsLanguageSystemHint =>
      'Opens this app\'s language page in your phone\'s settings';

  @override
  String get settingsLanguageOpenFailed =>
      'Could not open your phone\'s settings.';

  @override
  String get settingsStartup => 'At start';

  @override
  String get settingsDefaultServer => 'Default server';

  @override
  String get settingsDefaultServerNone => 'None, show the server list';

  @override
  String get serverDefaultBadge => 'Default';

  @override
  String get settingsLiveJobs => 'Live job progress';

  @override
  String get settingsLiveJobsHint =>
      'Scrubs, replications and updates on the lock screen and in notifications';

  @override
  String get jobKindScrub => 'Scrub';

  @override
  String get jobKindReplication => 'Replication';

  @override
  String get jobKindAppUpdate => 'App update';

  @override
  String get jobKindCloudSync => 'Cloud sync';

  @override
  String get jobKindCloudBackup => 'Cloud backup';

  @override
  String get jobKindRsync => 'Rsync task';

  @override
  String get jobKindSystemUpdate => 'System update';

  @override
  String get jobsStale => 'Not updating, open the app';

  @override
  String get jobsConnectionLost =>
      'Connection lost, progress may be out of date';

  @override
  String jobsMoreCount(int count) {
    return '+$count more';
  }

  @override
  String get jobsChannelName => 'Job progress';

  @override
  String get jobsChannelDescription =>
      'Progress of scrubs, replications and updates';

  @override
  String get serversLoadErrorTitle => 'Can\'t read your saved servers';

  @override
  String get serversLoadErrorBody =>
      'Nothing was deleted. The phone\'s secure storage did not answer. Try again; if it keeps failing, clear the list and add your servers again.';

  @override
  String get serversClearAction => 'Clear saved servers';

  @override
  String get serversClearTitle => 'Clear saved servers?';

  @override
  String get serversClearBody =>
      'Every server saved in this app is removed from it. Nothing changes on the servers themselves.';

  @override
  String get serversClearConfirm => 'Clear';

  @override
  String serverSaveFailed(String error) {
    return 'The server could not be saved: $error';
  }

  @override
  String get settingsLiveJobsNoExtension =>
      'This copy of the app has no lock screen extension (the sideloading tool removed it), so jobs show in the app only';

  @override
  String get settingsLiveJobsDisabled =>
      'Live Activities are turned off for this app in iOS Settings';

  @override
  String get jobsDismiss => 'Hide';

  @override
  String jobsRunningCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs running',
      one: '1 job running',
    );
    return '$_temp0';
  }

  @override
  String get snapshotsBrowse => 'Browse, roll back and clone';

  @override
  String get snapshotsSearch => 'Search snapshots';

  @override
  String get snapshotsNoMatch => 'No snapshots match';

  @override
  String snapshotsSummary(int count, String used) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count snapshots',
      one: '1 snapshot',
    );
    return '$_temp0 · $used used';
  }

  @override
  String get snapshotSort => 'Sort';

  @override
  String get snapshotSortNewest => 'Newest first';

  @override
  String get snapshotSortOldest => 'Oldest first';

  @override
  String get snapshotSortName => 'Name';

  @override
  String get snapshotSortSize => 'Size (used)';

  @override
  String snapshotRollbackNewer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'These $count newer snapshots will be destroyed:',
      one: 'This newer snapshot will be destroyed:',
    );
    return '$_temp0';
  }

  @override
  String snapshotRollbackMore(int count) {
    return 'and $count more';
  }

  @override
  String get snapshotRollbackClones => 'Also destroy clones of those snapshots';

  @override
  String get snapshotRollbackForce => 'Force unmount';

  @override
  String get snapshotClone => 'Clone';

  @override
  String snapshotCloneTitle(String name) {
    return 'Clone $name';
  }

  @override
  String get snapshotCloneBody =>
      'Makes a new dataset that starts as a copy of this snapshot. It takes no space until it changes.';

  @override
  String get snapshotCloneTarget => 'New dataset';

  @override
  String snapshotCloneInvalid(String pool) {
    return 'Use a path inside $pool, like $pool/copy';
  }

  @override
  String snapshotCloned(String name) {
    return 'Created $name';
  }

  @override
  String get historyTitle => 'History';

  @override
  String get historyRangeHour => 'Hour';

  @override
  String get historyRangeDay => 'Day';

  @override
  String get historyRangeWeek => 'Week';

  @override
  String get historyRangeMonth => 'Month';

  @override
  String get historyCpuTemperature => 'CPU temperature';

  @override
  String get historyInterface => 'Interface';

  @override
  String get historyDisk => 'Disk';

  @override
  String get historyDiskTemperature => 'Disk temperature';

  @override
  String get historyArc => 'ZFS cache (ARC)';

  @override
  String get historyNoData => 'No data for this period yet.';

  @override
  String historyStats(String average, String peak) {
    return 'Average $average · peak $peak';
  }

  @override
  String get historyUnavailable => 'This server has no history data.';

  @override
  String get historyChartFailed => 'Could not load this chart.';

  @override
  String get homeWidgetPools => 'Pools';

  @override
  String get homeWidgetSystem => 'System';

  @override
  String get homeWidgetAlerts => 'Alerts';

  @override
  String get homeWidgetCpu => 'CPU';

  @override
  String get homeWidgetMemory => 'RAM';

  @override
  String get homeWidgetUpdated => 'Updated';

  @override
  String get homeWidgetUnreachable => 'Can\'t reach the server';

  @override
  String get homeWidgetSetup => 'Open TrueNAS Mobile to set up';

  @override
  String get homeWidgetNoData => 'No data yet. Open the app.';

  @override
  String get homeWidgetNoPools => 'No pools';

  @override
  String get homeWidgetPoolsOk => 'All pools healthy';

  @override
  String homeWidgetPoolsAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pools need attention',
      one: '1 pool needs attention',
    );
    return '$_temp0';
  }

  @override
  String get homeWidgetAlertsNone => 'No active alerts';

  @override
  String homeWidgetAlertsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active alerts',
      one: '1 active alert',
    );
    return '$_temp0';
  }

  @override
  String get homeWidgetAppsNone => 'Apps up to date';

  @override
  String homeWidgetAppsUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps have updates',
      one: '1 app has an update',
    );
    return '$_temp0';
  }

  @override
  String get homeWidgetIdle => 'No scrub or cloud sync running';

  @override
  String homeWidgetMemoryText(String used, String total) {
    return '$used of $total';
  }

  @override
  String get settingsHomeWidgets => 'Home screen widgets';

  @override
  String get settingsHomeWidgetsHint =>
      'Keep widgets up to date in the background, about every 15 minutes. They also update while a server is open. Add them from your home screen; the phone decides when a refresh really runs.';
}
