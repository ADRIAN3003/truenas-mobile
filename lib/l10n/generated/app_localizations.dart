import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Application name shown in the task switcher and title bar.
  ///
  /// In en, this message translates to:
  /// **'TrueNAS Mobile'**
  String get appTitle;

  /// Title of the home screen that lists saved TrueNAS servers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get serversTitle;

  /// Headline shown when no servers have been added.
  ///
  /// In en, this message translates to:
  /// **'No servers yet'**
  String get serversEmptyTitle;

  /// Explanation shown when no servers have been added.
  ///
  /// In en, this message translates to:
  /// **'Add a TrueNAS server (25.04 or newer) to start managing it.'**
  String get serversEmptyBody;

  /// Button that opens the form for adding a TrueNAS server.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get addServer;

  /// Title of the form for editing a saved server.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get editServer;

  /// Menu item that opens the edit form.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Menu item or button that deletes something.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Button that dismisses a dialog without acting.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Button that saves the form.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Button that retries a failed connection.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// Title of the dialog confirming that a saved server is deleted.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteServerTitle(String name);

  /// Body of the delete confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'The server is only removed from this app. Nothing changes on the server itself.'**
  String get deleteServerBody;

  /// Label of the server name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// Example server name shown in the empty name field.
  ///
  /// In en, this message translates to:
  /// **'Home NAS'**
  String get fieldNameHint;

  /// Label of the server address field.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// Example address shown in the empty address field.
  ///
  /// In en, this message translates to:
  /// **'nas.local or https://192.168.1.10'**
  String get fieldAddressHint;

  /// Label of the username field.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fieldUsername;

  /// Label of the API key field.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get fieldApiKey;

  /// Helper text under the API key field.
  ///
  /// In en, this message translates to:
  /// **'Create one in TrueNAS under Credentials > Users > API keys.'**
  String get fieldApiKeyHelp;

  /// Label of the password field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// Segment for signing in with an API key.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get authApiKey;

  /// Segment for signing in with username and password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// Error shown under an empty required field.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get validationRequired;

  /// Error shown when the server address cannot be parsed.
  ///
  /// In en, this message translates to:
  /// **'Enter a host name or an http(s) address'**
  String get validationAddress;

  /// Error shown when an API key is used with an http:// address.
  ///
  /// In en, this message translates to:
  /// **'API keys need HTTPS. TrueNAS revokes keys that are sent over plain HTTP.'**
  String get validationApiKeyHttps;

  /// Button that tries to connect with the values in the form.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// Snackbar shown after a successful connection test.
  ///
  /// In en, this message translates to:
  /// **'Connected to {hostname} (TrueNAS {version})'**
  String testSucceeded(String hostname, String version);

  /// Shown while connecting to a server.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// Title of the dialog shown for a self-signed or unknown certificate.
  ///
  /// In en, this message translates to:
  /// **'Trust this certificate?'**
  String get certificateTitle;

  /// Title of the dialog shown when a pinned certificate no longer matches.
  ///
  /// In en, this message translates to:
  /// **'Certificate changed'**
  String get certificateChangedTitle;

  /// Explanation in the certificate dialog.
  ///
  /// In en, this message translates to:
  /// **'The server\'s certificate is not signed by an authority this device trusts. This is normal for the self-signed certificate TrueNAS creates. Only trust it if the fingerprint matches the one in TrueNAS under Credentials > Certificates.'**
  String get certificateBody;

  /// Warning shown when a pinned certificate changed.
  ///
  /// In en, this message translates to:
  /// **'The server\'s certificate is different from the one you trusted before. If you did not replace it, someone may be intercepting the connection.'**
  String get certificateChangedBody;

  /// Label for the certificate subject.
  ///
  /// In en, this message translates to:
  /// **'Issued to'**
  String get certificateSubject;

  /// Label for the certificate issuer.
  ///
  /// In en, this message translates to:
  /// **'Issued by'**
  String get certificateIssuer;

  /// Label for the certificate expiry date.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get certificateExpires;

  /// Label for the certificate fingerprint.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 fingerprint'**
  String get certificateFingerprint;

  /// Button that trusts and pins the certificate.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get trust;

  /// Title of the dialog asking for a 2FA code.
  ///
  /// In en, this message translates to:
  /// **'Two-factor code'**
  String get otpTitle;

  /// Body of the 2FA dialog.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app.'**
  String get otpBody;

  /// Button that submits the 2FA code.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpSubmit;

  /// Error when credentials are wrong.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the sign-in. Check the username and the API key or password.'**
  String get errorLoginRejected;

  /// Error when the credentials have expired.
  ///
  /// In en, this message translates to:
  /// **'The API key or password has expired.'**
  String get errorLoginExpired;

  /// Error when the server API is older than 25.04.
  ///
  /// In en, this message translates to:
  /// **'This server is too old. TrueNAS Mobile needs TrueNAS 25.04 or newer.'**
  String get errorUnsupported;

  /// Error when the user declined the certificate.
  ///
  /// In en, this message translates to:
  /// **'The certificate was not trusted, so the app did not connect.'**
  String get errorCertificate;

  /// Generic connection error.
  ///
  /// In en, this message translates to:
  /// **'Could not connect: {details}'**
  String errorGeneric(String details);

  /// Label for the server host name.
  ///
  /// In en, this message translates to:
  /// **'Hostname'**
  String get infoHostname;

  /// Label for the TrueNAS version.
  ///
  /// In en, this message translates to:
  /// **'TrueNAS version'**
  String get infoVersion;

  /// Label for the API version in use.
  ///
  /// In en, this message translates to:
  /// **'API version'**
  String get infoApiVersion;

  /// Label for the CPU model.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get infoModel;

  /// Label for the number of CPU cores.
  ///
  /// In en, this message translates to:
  /// **'CPU cores'**
  String get infoCores;

  /// Label for installed memory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get infoMemory;

  /// Label for the time since boot.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get infoUptime;

  /// Label for the signed-in user.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get infoSignedInAs;

  /// Shown when the user cancels a certificate or 2FA prompt.
  ///
  /// In en, this message translates to:
  /// **'Connection cancelled.'**
  String get errorCancelled;

  /// Bottom navigation tab for the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get tabDashboard;

  /// Bottom navigation tab for alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get tabAlerts;

  /// Bottom navigation tab for background jobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get tabJobs;

  /// Title of the CPU usage card.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get cpuTitle;

  /// CPU temperature value.
  ///
  /// In en, this message translates to:
  /// **'{temp} °C'**
  String cpuTemperature(String temp);

  /// Title of the memory card.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memoryTitle;

  /// Memory usage summary.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} used'**
  String memoryUsedOf(String used, String total);

  /// Legend label for memory used by services and apps.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get memoryServices;

  /// Legend label for memory used by the ZFS ARC cache.
  ///
  /// In en, this message translates to:
  /// **'ZFS cache'**
  String get memoryArc;

  /// Legend label for free memory.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get memoryFree;

  /// Title of the network throughput card.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkTitle;

  /// Legend label for received traffic.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get networkIn;

  /// Legend label for sent traffic.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get networkOut;

  /// Title of the storage pools card.
  ///
  /// In en, this message translates to:
  /// **'Pools'**
  String get poolsTitle;

  /// Shown when the server has no storage pools.
  ///
  /// In en, this message translates to:
  /// **'No pools'**
  String get poolsEmpty;

  /// Pool usage summary.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total}'**
  String poolUsage(String used, String total);

  /// Title of the alerts summary card.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// Shown when there are no active alerts.
  ///
  /// In en, this message translates to:
  /// **'No active alerts'**
  String get alertsNone;

  /// Number of critical alerts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 critical} other{{count} critical}}'**
  String alertsCritical(int count);

  /// Number of warning alerts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 warning} other{{count} warnings}}'**
  String alertsWarning(int count);

  /// Number of informational alerts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 notice} other{{count} notices}}'**
  String alertsInfo(int count);

  /// Heading for alerts that are not dismissed.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get alertsActive;

  /// Heading for dismissed alerts.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get alertsDismissed;

  /// Action that dismisses an alert.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get alertDismiss;

  /// Action that restores a dismissed alert.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get alertRestore;

  /// Label for critical alert level.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get levelCritical;

  /// Label for warning alert level.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get levelWarning;

  /// Label for informational alert level.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get levelInfo;

  /// Shown when there are no jobs.
  ///
  /// In en, this message translates to:
  /// **'No recent jobs'**
  String get jobsEmpty;

  /// Action that aborts a running job.
  ///
  /// In en, this message translates to:
  /// **'Abort'**
  String get jobAbort;

  /// Title of the abort confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Abort this job?'**
  String get jobAbortTitle;

  /// Job state label.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get jobStateWaiting;

  /// Job state label.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get jobStateRunning;

  /// Job state label.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get jobStateSuccess;

  /// Job state label.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get jobStateFailed;

  /// Job state label.
  ///
  /// In en, this message translates to:
  /// **'Aborted'**
  String get jobStateAborted;

  /// Button that closes a dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Shown until the first live statistics sample arrives.
  ///
  /// In en, this message translates to:
  /// **'Waiting for live data…'**
  String get liveWaiting;

  /// Title of the system information card.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTitle;

  /// Bottom navigation tab for storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get tabStorage;

  /// Title of the disks screen and its entry.
  ///
  /// In en, this message translates to:
  /// **'Disks'**
  String get disksTitle;

  /// Subtitle of the disks entry.
  ///
  /// In en, this message translates to:
  /// **'Health, temperature and pool membership'**
  String get disksSubtitle;

  /// Shown when no disks are reported.
  ///
  /// In en, this message translates to:
  /// **'No disks'**
  String get disksEmpty;

  /// Shown for disks that do not belong to a pool.
  ///
  /// In en, this message translates to:
  /// **'Not in a pool'**
  String get diskUnused;

  /// Pool a disk belongs to.
  ///
  /// In en, this message translates to:
  /// **'Pool {pool}'**
  String diskPool(String pool);

  /// Disk serial number.
  ///
  /// In en, this message translates to:
  /// **'Serial {serial}'**
  String diskSerial(String serial);

  /// Disk type label for solid-state disks.
  ///
  /// In en, this message translates to:
  /// **'SSD'**
  String get diskSsd;

  /// Disk rotation rate.
  ///
  /// In en, this message translates to:
  /// **'{rpm} rpm'**
  String diskRpm(int rpm);

  /// Title of the scrub card.
  ///
  /// In en, this message translates to:
  /// **'Scrub'**
  String get scrubTitle;

  /// Scrub progress.
  ///
  /// In en, this message translates to:
  /// **'Scrub running: {percent}%'**
  String scrubRunning(String percent);

  /// Resilver progress.
  ///
  /// In en, this message translates to:
  /// **'Resilver running: {percent}%'**
  String resilverRunning(String percent);

  /// Paused scrub progress.
  ///
  /// In en, this message translates to:
  /// **'Scrub paused at {percent}%'**
  String scrubPaused(String percent);

  /// Result of the last scrub.
  ///
  /// In en, this message translates to:
  /// **'Last scrub finished {date} with {errors, plural, =0{no errors} =1{1 error} other{{errors} errors}}'**
  String scrubFinished(String date, int errors);

  /// Shown when the last scrub was canceled.
  ///
  /// In en, this message translates to:
  /// **'Last scrub was stopped'**
  String get scrubCanceled;

  /// Shown when the pool has never been scrubbed.
  ///
  /// In en, this message translates to:
  /// **'No scrub has run yet'**
  String get scrubNever;

  /// Button that starts a scrub.
  ///
  /// In en, this message translates to:
  /// **'Start scrub'**
  String get scrubStart;

  /// Button that pauses a scrub.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get scrubPause;

  /// Button that resumes a paused scrub.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get scrubResume;

  /// Button that stops a scrub.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get scrubStop;

  /// Snackbar after a scrub starts.
  ///
  /// In en, this message translates to:
  /// **'Scrub started'**
  String get scrubStarted;

  /// Confirmation title for stopping a scrub.
  ///
  /// In en, this message translates to:
  /// **'Stop the scrub on {pool}?'**
  String scrubStopTitle(String pool);

  /// Confirmation body for stopping a scrub.
  ///
  /// In en, this message translates to:
  /// **'Progress is lost and the next scrub starts from the beginning.'**
  String get scrubStopBody;

  /// Title of the pool layout card.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get topologyTitle;

  /// Pool vdev group name.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get vdevGroupData;

  /// Pool vdev group name.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get vdevGroupLog;

  /// Pool vdev group name.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get vdevGroupCache;

  /// Pool vdev group name.
  ///
  /// In en, this message translates to:
  /// **'Spare'**
  String get vdevGroupSpare;

  /// Pool vdev group name.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get vdevGroupSpecial;

  /// Pool vdev group name.
  ///
  /// In en, this message translates to:
  /// **'Dedup'**
  String get vdevGroupDedup;

  /// Error counters of a vdev or disk.
  ///
  /// In en, this message translates to:
  /// **'{read} read, {write} write, {checksum} checksum errors'**
  String vdevErrors(int read, int write, int checksum);

  /// Free space in a pool.
  ///
  /// In en, this message translates to:
  /// **'{free} free'**
  String poolFree(String free);

  /// Title of the datasets screen and its entry.
  ///
  /// In en, this message translates to:
  /// **'Datasets'**
  String get datasetsTitle;

  /// Shown when a pool has no datasets.
  ///
  /// In en, this message translates to:
  /// **'No datasets'**
  String get datasetsEmpty;

  /// Button and dialog title for creating a dataset.
  ///
  /// In en, this message translates to:
  /// **'Create dataset'**
  String get datasetCreate;

  /// Snackbar after creating a dataset.
  ///
  /// In en, this message translates to:
  /// **'Created {name}'**
  String datasetCreated(String name);

  /// Label of the parent dataset dropdown.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get datasetParent;

  /// Label of the new dataset name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get datasetNameField;

  /// Validation error for dataset names.
  ///
  /// In en, this message translates to:
  /// **'Use letters, numbers, - _ . and : only'**
  String get datasetNameInvalid;

  /// Segment for creating a filesystem dataset.
  ///
  /// In en, this message translates to:
  /// **'Dataset'**
  String get datasetTypeFilesystem;

  /// Segment for creating a zvol.
  ///
  /// In en, this message translates to:
  /// **'Zvol'**
  String get datasetTypeVolume;

  /// Label of the zvol size field.
  ///
  /// In en, this message translates to:
  /// **'Size (GiB)'**
  String get datasetSizeGib;

  /// Validation error for zvol size.
  ///
  /// In en, this message translates to:
  /// **'Enter a size above 0'**
  String get datasetSizeInvalid;

  /// Label for used space.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get datasetUsed;

  /// Label for available space.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get datasetAvailable;

  /// Label for the compression algorithm.
  ///
  /// In en, this message translates to:
  /// **'Compression'**
  String get datasetCompression;

  /// Label for the compression ratio.
  ///
  /// In en, this message translates to:
  /// **'Compression ratio'**
  String get datasetCompressRatio;

  /// Label for the mount point.
  ///
  /// In en, this message translates to:
  /// **'Mount point'**
  String get datasetMountpoint;

  /// Label for the size of a zvol.
  ///
  /// In en, this message translates to:
  /// **'Zvol size'**
  String get datasetVolsize;

  /// Label for encryption state.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get datasetEncryption;

  /// Value when a dataset is encrypted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get datasetEncrypted;

  /// Value when an encrypted dataset is locked.
  ///
  /// In en, this message translates to:
  /// **'Encrypted, locked'**
  String get datasetLocked;

  /// Value when a dataset is not encrypted.
  ///
  /// In en, this message translates to:
  /// **'Not encrypted'**
  String get datasetNotEncrypted;

  /// Label marking a dataset as a zvol.
  ///
  /// In en, this message translates to:
  /// **'Zvol'**
  String get datasetZvol;

  /// Menu item that deletes a dataset.
  ///
  /// In en, this message translates to:
  /// **'Delete dataset'**
  String get datasetDelete;

  /// Confirmation title for deleting a dataset.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String datasetDeleteTitle(String name);

  /// Confirmation body for deleting a dataset.
  ///
  /// In en, this message translates to:
  /// **'This permanently destroys the dataset, its child datasets and all their snapshots and data. It cannot be undone.'**
  String get datasetDeleteBody;

  /// Hint for the type-to-confirm field.
  ///
  /// In en, this message translates to:
  /// **'Type {name} to confirm'**
  String typeNameToConfirm(String name);

  /// Snackbar after deleting a dataset.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String datasetDeleted(String name);

  /// Title of the snapshots section.
  ///
  /// In en, this message translates to:
  /// **'Snapshots'**
  String get snapshotsTitle;

  /// Shown when a dataset has no snapshots.
  ///
  /// In en, this message translates to:
  /// **'No snapshots'**
  String get snapshotsEmpty;

  /// Button and dialog title for creating a snapshot.
  ///
  /// In en, this message translates to:
  /// **'Create snapshot'**
  String get snapshotCreate;

  /// Label of the snapshot name field.
  ///
  /// In en, this message translates to:
  /// **'Snapshot name'**
  String get snapshotNameField;

  /// Checkbox to snapshot child datasets too.
  ///
  /// In en, this message translates to:
  /// **'Include child datasets'**
  String get snapshotRecursive;

  /// Snackbar after creating a snapshot.
  ///
  /// In en, this message translates to:
  /// **'Snapshot created'**
  String get snapshotCreated;

  /// Menu item that deletes a snapshot.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get snapshotDelete;

  /// Confirmation title for deleting a snapshot.
  ///
  /// In en, this message translates to:
  /// **'Delete snapshot {name}?'**
  String snapshotDeleteTitle(String name);

  /// Confirmation body for deleting a snapshot.
  ///
  /// In en, this message translates to:
  /// **'The snapshot is destroyed. Data in the live dataset is not affected.'**
  String get snapshotDeleteBody;

  /// Snackbar after deleting a snapshot.
  ///
  /// In en, this message translates to:
  /// **'Snapshot deleted'**
  String get snapshotDeleted;

  /// Menu item that rolls back to a snapshot.
  ///
  /// In en, this message translates to:
  /// **'Roll back'**
  String get snapshotRollback;

  /// Confirmation title for rolling back.
  ///
  /// In en, this message translates to:
  /// **'Roll back {dataset}?'**
  String snapshotRollbackTitle(String dataset);

  /// Confirmation body for rolling back.
  ///
  /// In en, this message translates to:
  /// **'The dataset returns to its state at snapshot {name}. All changes made since then are lost, and newer snapshots are destroyed.'**
  String snapshotRollbackBody(String name);

  /// Snackbar after rolling back.
  ///
  /// In en, this message translates to:
  /// **'Rolled back to {name}'**
  String snapshotRolledBack(String name);

  /// Snapshot size line.
  ///
  /// In en, this message translates to:
  /// **'{used} used · {referenced} referenced'**
  String snapshotSize(String used, String referenced);

  /// Button that creates something.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
