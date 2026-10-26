import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hu.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hu'),
  ];

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

  /// Heading of the Wake-on-LAN part of the server form.
  ///
  /// In en, this message translates to:
  /// **'Wake-on-LAN'**
  String get wolSection;

  /// Explains the Wake-on-LAN part of the server form.
  ///
  /// In en, this message translates to:
  /// **'Optional. Wakes this server from the server list with a magic packet when it is asleep or off. Wake-on-LAN must be switched on in the NAS\'s BIOS or UEFI.'**
  String get wolIntro;

  /// Field label for the MAC address of the NAS's network card.
  ///
  /// In en, this message translates to:
  /// **'MAC address'**
  String get wolMac;

  /// Example MAC address in the empty field.
  ///
  /// In en, this message translates to:
  /// **'AA:BB:CC:DD:EE:FF'**
  String get wolMacHint;

  /// Error under a MAC address that cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Enter a MAC address like AA:BB:CC:DD:EE:FF'**
  String get wolMacInvalid;

  /// Field label for where the magic packet is sent.
  ///
  /// In en, this message translates to:
  /// **'Broadcast address'**
  String get wolBroadcast;

  /// Help under the broadcast address field.
  ///
  /// In en, this message translates to:
  /// **'Empty means 255.255.255.255. If the NAS does not wake, use your network\'s own, such as 192.168.1.255.'**
  String get wolBroadcastHelp;

  /// Field label for the UDP port of the magic packet.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get wolPort;

  /// Error under an invalid port.
  ///
  /// In en, this message translates to:
  /// **'Enter a port from 1 to 65535'**
  String get wolPortInvalid;

  /// Button that reads the MAC address from the running server.
  ///
  /// In en, this message translates to:
  /// **'Get the MAC address from the server'**
  String get wolFetch;

  /// Shown when the server lists no MAC address.
  ///
  /// In en, this message translates to:
  /// **'The server reported no network card with a MAC address.'**
  String get wolFetchNone;

  /// Title of the choice between network cards.
  ///
  /// In en, this message translates to:
  /// **'Which network card wakes the server?'**
  String get wolChooseCard;

  /// Button and tooltip that sends the magic packet.
  ///
  /// In en, this message translates to:
  /// **'Wake up'**
  String get wolWake;

  /// Shown after the magic packet was sent.
  ///
  /// In en, this message translates to:
  /// **'Wake-up sent to {name}. It can take a minute to start.'**
  String wolSent(String name);

  /// Shown when the magic packet could not be sent.
  ///
  /// In en, this message translates to:
  /// **'Could not send the wake-up: {error}'**
  String wolFailed(String error);

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
  /// **'Home'**
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

  /// Shown in the pools card when the server did not answer the pool query.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the pools: {reason}'**
  String poolsLoadFailed(String reason);

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

  /// Label of the disk temperature on the disk screen.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get diskTemperature;

  /// Title of the S.M.A.R.T. card on the disk screen.
  ///
  /// In en, this message translates to:
  /// **'S.M.A.R.T.'**
  String get diskSmartTitle;

  /// Shown when S.M.A.R.T. is switched off for a disk.
  ///
  /// In en, this message translates to:
  /// **'S.M.A.R.T. monitoring is switched off for this disk.'**
  String get diskSmartOff;

  /// Shown when the server has no S.M.A.R.T. test API.
  ///
  /// In en, this message translates to:
  /// **'This server does not report S.M.A.R.T. test results.'**
  String get diskSmartUnavailable;

  /// Shown when a disk has no self-test log entries.
  ///
  /// In en, this message translates to:
  /// **'No self-test has run yet.'**
  String get diskSmartNoTests;

  /// Summary line when the newest finished self-test passed.
  ///
  /// In en, this message translates to:
  /// **'Last self-test passed'**
  String get diskSmartLastPassed;

  /// Summary line when the newest finished self-test failed.
  ///
  /// In en, this message translates to:
  /// **'Last self-test failed'**
  String get diskSmartLastFailed;

  /// Summary line when the newest finished self-test was aborted.
  ///
  /// In en, this message translates to:
  /// **'Last self-test was aborted'**
  String get diskSmartLastAborted;

  /// Progress of the running self-test.
  ///
  /// In en, this message translates to:
  /// **'{percent}% done'**
  String diskSmartRunning(String percent);

  /// Button that starts a S.M.A.R.T. self-test.
  ///
  /// In en, this message translates to:
  /// **'Run a test'**
  String get diskSmartRun;

  /// Title of the sheet that picks the kind of self-test.
  ///
  /// In en, this message translates to:
  /// **'Run a self-test'**
  String get diskSmartRunTitle;

  /// Snackbar after starting a self-test.
  ///
  /// In en, this message translates to:
  /// **'{test} test started on {disk}'**
  String diskSmartStarted(String test, String disk);

  /// Name of the short S.M.A.R.T. self-test.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get smartTestShort;

  /// What the short self-test does.
  ///
  /// In en, this message translates to:
  /// **'a few minutes'**
  String get smartTestShortHint;

  /// Name of the long S.M.A.R.T. self-test.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get smartTestLong;

  /// What the long self-test does.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get smartTestLongHint;

  /// Name of the conveyance S.M.A.R.T. self-test.
  ///
  /// In en, this message translates to:
  /// **'Conveyance'**
  String get smartTestConveyance;

  /// What the conveyance self-test does.
  ///
  /// In en, this message translates to:
  /// **'a few minutes, ATA only'**
  String get smartTestConveyanceHint;

  /// Name of the offline S.M.A.R.T. data collection.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get smartTestOffline;

  /// What the offline data collection does.
  ///
  /// In en, this message translates to:
  /// **'ATA only'**
  String get smartTestOfflineHint;

  /// Heading above the list of past self-tests.
  ///
  /// In en, this message translates to:
  /// **'Self-test history'**
  String get diskSmartHistory;

  /// Self-test status: finished without error.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get smartStatusPassed;

  /// Self-test status: still running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get smartStatusRunning;

  /// Self-test status: stopped before it finished.
  ///
  /// In en, this message translates to:
  /// **'Aborted'**
  String get smartStatusAborted;

  /// Self-test status: found a problem.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get smartStatusFailed;

  /// When a self-test ran, in power-on hours of the disk.
  ///
  /// In en, this message translates to:
  /// **'After {hours} power-on hours'**
  String diskSmartLifetime(int hours);

  /// Block address of the first error a self-test found.
  ///
  /// In en, this message translates to:
  /// **'First error at block {lba}'**
  String diskSmartFirstError(int lba);

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
  /// **'The dataset returns to its state at snapshot {name}. Everything changed since then is lost.'**
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

  /// Bottom navigation tab for shares and services.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get tabShares;

  /// Title of the services screen.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get servicesTitle;

  /// Subtitle of the services entry.
  ///
  /// In en, this message translates to:
  /// **'Start, stop, and choose what starts on boot'**
  String get servicesSubtitle;

  /// Shown when the server lists no services.
  ///
  /// In en, this message translates to:
  /// **'No services'**
  String get servicesEmpty;

  /// Service state label.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get serviceRunning;

  /// Service state label.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get serviceStopped;

  /// Starts a service.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get serviceStart;

  /// Stops a service.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get serviceStop;

  /// Restarts a service.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get serviceRestart;

  /// Switch that makes a service start when the server boots.
  ///
  /// In en, this message translates to:
  /// **'Start on boot'**
  String get serviceStartOnBoot;

  /// Confirmation title for stopping a service.
  ///
  /// In en, this message translates to:
  /// **'Stop {name}?'**
  String serviceStopTitle(String name);

  /// Confirmation body for stopping a service.
  ///
  /// In en, this message translates to:
  /// **'Clients using this service lose access until it is started again.'**
  String get serviceStopBody;

  /// Snackbar after starting or restarting a service.
  ///
  /// In en, this message translates to:
  /// **'{name} is running'**
  String serviceStartedMessage(String name);

  /// Snackbar after stopping a service.
  ///
  /// In en, this message translates to:
  /// **'{name} stopped'**
  String serviceStoppedMessage(String name);

  /// Banner on a share list when its service is not running.
  ///
  /// In en, this message translates to:
  /// **'The {name} service is stopped, so these shares can\'t be reached.'**
  String serviceNotRunning(String name);

  /// Title of the SMB share list.
  ///
  /// In en, this message translates to:
  /// **'SMB shares'**
  String get smbTitle;

  /// Title of the NFS share list.
  ///
  /// In en, this message translates to:
  /// **'NFS shares'**
  String get nfsTitle;

  /// Number of shares of one protocol.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No shares} =1{1 share} other{{count} shares}}'**
  String sharesCount(int count);

  /// Shown when a share list is empty.
  ///
  /// In en, this message translates to:
  /// **'No shares yet'**
  String get sharesEmpty;

  /// Button that creates a share.
  ///
  /// In en, this message translates to:
  /// **'Add share'**
  String get shareCreate;

  /// Title of the share edit dialog.
  ///
  /// In en, this message translates to:
  /// **'Edit share'**
  String get shareEdit;

  /// Field for the SMB share name.
  ///
  /// In en, this message translates to:
  /// **'Share name'**
  String get shareName;

  /// Field for the dataset folder a share exports.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get sharePath;

  /// Field for a share's description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get shareComment;

  /// Switch that makes a share read only.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get shareReadOnly;

  /// Switch for SMB share browsability.
  ///
  /// In en, this message translates to:
  /// **'Visible when browsing the network'**
  String get shareBrowsable;

  /// Switch that turns a share on or off.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get shareEnabled;

  /// Label for a share that is turned off.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get shareDisabled;

  /// Label for a share whose encrypted dataset is locked.
  ///
  /// In en, this message translates to:
  /// **'Dataset locked'**
  String get shareLocked;

  /// Shown when there is no dataset to share.
  ///
  /// In en, this message translates to:
  /// **'Create a dataset first. A share always points at a dataset\'s folder.'**
  String get shareNoDatasets;

  /// Snackbar after creating a share.
  ///
  /// In en, this message translates to:
  /// **'Share added'**
  String get shareCreated;

  /// Snackbar after changing a share.
  ///
  /// In en, this message translates to:
  /// **'Share saved'**
  String get shareSaved;

  /// Button that deletes a share.
  ///
  /// In en, this message translates to:
  /// **'Delete share'**
  String get shareDelete;

  /// Confirmation title for deleting a share.
  ///
  /// In en, this message translates to:
  /// **'Delete share {name}?'**
  String shareDeleteTitle(String name);

  /// Confirmation body for deleting a share.
  ///
  /// In en, this message translates to:
  /// **'Clients can no longer reach it. The files in {path} are kept.'**
  String shareDeleteBody(String path);

  /// Snackbar after deleting a share.
  ///
  /// In en, this message translates to:
  /// **'Share deleted'**
  String get shareDeleted;

  /// NFS export without host or network limits.
  ///
  /// In en, this message translates to:
  /// **'Any host can connect'**
  String get nfsAllowedEveryone;

  /// NFS export limited to some hosts or networks.
  ///
  /// In en, this message translates to:
  /// **'Allowed: {list}'**
  String nfsAllowed(String list);

  /// Title of the iSCSI screen.
  ///
  /// In en, this message translates to:
  /// **'iSCSI'**
  String get iscsiTitle;

  /// Section heading for iSCSI targets.
  ///
  /// In en, this message translates to:
  /// **'Targets'**
  String get iscsiTargets;

  /// Section heading for iSCSI extents.
  ///
  /// In en, this message translates to:
  /// **'Extents'**
  String get iscsiExtents;

  /// Summary of iSCSI configuration.
  ///
  /// In en, this message translates to:
  /// **'Targets: {targets} · Extents: {extents}'**
  String iscsiSummary(int targets, int extents);

  /// Shown when no iSCSI target exists.
  ///
  /// In en, this message translates to:
  /// **'No iSCSI targets'**
  String get iscsiEmpty;

  /// Title of the NVMe-oF screen.
  ///
  /// In en, this message translates to:
  /// **'NVMe over Fabrics'**
  String get nvmetTitle;

  /// Summary of NVMe-oF configuration.
  ///
  /// In en, this message translates to:
  /// **'Subsystems: {count}'**
  String nvmetSummary(int count);

  /// Shown when no subsystem exists.
  ///
  /// In en, this message translates to:
  /// **'No NVMe-oF subsystems'**
  String get nvmetEmpty;

  /// NVMe-oF subsystem open to all hosts.
  ///
  /// In en, this message translates to:
  /// **'Any host can connect'**
  String get nvmetAnyHost;

  /// NVMe-oF subsystem limited to some hosts.
  ///
  /// In en, this message translates to:
  /// **'Only allowed hosts can connect'**
  String get nvmetAllowedHosts;

  /// Note on read-only screens.
  ///
  /// In en, this message translates to:
  /// **'View only for now. Use the TrueNAS web interface to change these.'**
  String get viewOnlyNote;

  /// Bottom navigation tab for apps, VMs and containers.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get tabApps;

  /// Bottom navigation tab with further sections.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tabMore;

  /// Section heading for Docker apps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get appsTitle;

  /// Shown when no app is installed.
  ///
  /// In en, this message translates to:
  /// **'No apps installed'**
  String get appsEmpty;

  /// Section heading for VMs.
  ///
  /// In en, this message translates to:
  /// **'Virtual machines'**
  String get vmsTitle;

  /// Shown when no VM exists.
  ///
  /// In en, this message translates to:
  /// **'No virtual machines'**
  String get vmsEmpty;

  /// Section heading for containers.
  ///
  /// In en, this message translates to:
  /// **'Containers'**
  String get containersTitle;

  /// Shown when no container exists.
  ///
  /// In en, this message translates to:
  /// **'No containers'**
  String get containersEmpty;

  /// Workload state.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get stateRunning;

  /// Workload state.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stateStopped;

  /// Workload state while it starts or deploys.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get stateDeploying;

  /// Workload state.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get stateStopping;

  /// Workload state for a suspended VM or frozen container.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get stateSuspended;

  /// Workload state after a failure.
  ///
  /// In en, this message translates to:
  /// **'Crashed'**
  String get stateCrashed;

  /// Workload state the app doesn't recognise.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get stateUnknown;

  /// Starts an app, VM or container.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get actionStart;

  /// Stops an app, VM or container.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get actionStop;

  /// Restarts an app, VM or container.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get actionRestart;

  /// Cuts a VM's power.
  ///
  /// In en, this message translates to:
  /// **'Power off'**
  String get actionPowerOff;

  /// Upgrades an app.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get actionUpgrade;

  /// Deletes an app.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Snackbar after starting.
  ///
  /// In en, this message translates to:
  /// **'{name} started'**
  String actionStarted(String name);

  /// Snackbar after stopping.
  ///
  /// In en, this message translates to:
  /// **'{name} stopped'**
  String actionStopped(String name);

  /// Snackbar after restarting.
  ///
  /// In en, this message translates to:
  /// **'{name} restarted'**
  String actionRestarted(String name);

  /// Snackbar after powering off a VM.
  ///
  /// In en, this message translates to:
  /// **'{name} powered off'**
  String actionPoweredOff(String name);

  /// Snackbar after upgrading an app.
  ///
  /// In en, this message translates to:
  /// **'{name} upgraded'**
  String actionUpgraded(String name);

  /// Snackbar after deleting an app.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String actionDeleted(String name);

  /// Confirmation title for stopping an app, VM or container.
  ///
  /// In en, this message translates to:
  /// **'Stop {name}?'**
  String stopTitle(String name);

  /// Confirmation body for stopping an app or container.
  ///
  /// In en, this message translates to:
  /// **'It can\'t be reached until it is started again.'**
  String get stopBody;

  /// Confirmation body for stopping a VM.
  ///
  /// In en, this message translates to:
  /// **'The guest is asked to shut down. If it hasn\'t within its shutdown timeout, it is powered off.'**
  String get vmStopBody;

  /// Confirmation title for restarting.
  ///
  /// In en, this message translates to:
  /// **'Restart {name}?'**
  String restartTitle(String name);

  /// Confirmation body for restarting.
  ///
  /// In en, this message translates to:
  /// **'It is unavailable for a moment while it restarts.'**
  String get restartBody;

  /// Confirmation title for powering off a VM.
  ///
  /// In en, this message translates to:
  /// **'Power off {name}?'**
  String vmPowerOffTitle(String name);

  /// Confirmation body for powering off a VM.
  ///
  /// In en, this message translates to:
  /// **'This cuts power immediately, like pulling the plug. Unsaved work inside the VM can be lost.'**
  String get vmPowerOffBody;

  /// Confirmation title for upgrading an app.
  ///
  /// In en, this message translates to:
  /// **'Upgrade {name}?'**
  String appUpgradeTitle(String name);

  /// Confirmation body for upgrading an app.
  ///
  /// In en, this message translates to:
  /// **'{name} goes from {from} to {to}. The app restarts during the upgrade.'**
  String appUpgradeBody(String name, String from, String to);

  /// Confirmation title for deleting an app.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String appDeleteTitle(String name);

  /// Confirmation body for deleting an app.
  ///
  /// In en, this message translates to:
  /// **'The app and its containers and images are removed. Data in its volumes and host folders is kept.'**
  String get appDeleteBody;

  /// Badge on an app with a newer version.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get appUpdateAvailable;

  /// Badge on an app with newer container images.
  ///
  /// In en, this message translates to:
  /// **'Newer images available'**
  String get appImageUpdates;

  /// Label for an app's installed version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get appVersion;

  /// Label for an app's newest version.
  ///
  /// In en, this message translates to:
  /// **'Latest version'**
  String get appLatestVersion;

  /// Label for an app's container count.
  ///
  /// In en, this message translates to:
  /// **'Running containers'**
  String get appContainersRunning;

  /// Label for an app's container images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get appImages;

  /// Heading for an app's web addresses.
  ///
  /// In en, this message translates to:
  /// **'Web interfaces'**
  String get appPortals;

  /// Label for an app installed from a compose file.
  ///
  /// In en, this message translates to:
  /// **'Custom app'**
  String get appCustom;

  /// Heading for an app's notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get appNotes;

  /// VM size line.
  ///
  /// In en, this message translates to:
  /// **'{vcpus} vCPU · {memory}'**
  String vmSummary(int vcpus, String memory);

  /// Label for a VM or container that starts on boot.
  ///
  /// In en, this message translates to:
  /// **'Starts on boot'**
  String get vmAutostart;

  /// Label for an Incus virtual machine listed among containers.
  ///
  /// In en, this message translates to:
  /// **'Incus VM'**
  String get containerIsVm;

  /// Snackbar after copying text.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// Section header in the More tab.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get moreAccounts;

  /// Section header in the More tab.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get moreSystem;

  /// Section header in the More tab.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get moreActivity;

  /// Users screen title.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get usersTitle;

  /// Shown when there are no non-built-in users.
  ///
  /// In en, this message translates to:
  /// **'No users yet. System accounts are hidden.'**
  String get usersEmpty;

  /// Toggle to include built-in accounts.
  ///
  /// In en, this message translates to:
  /// **'Show system accounts'**
  String get usersShowBuiltin;

  /// Button to create a user.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get userCreate;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get userUsername;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get userFullName;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get userPassword;

  /// Switch label when creating a user.
  ///
  /// In en, this message translates to:
  /// **'Allow SMB access'**
  String get userSmb;

  /// Validation message.
  ///
  /// In en, this message translates to:
  /// **'Use lowercase letters, digits, - or _, starting with a letter'**
  String get userUsernameInvalid;

  /// Validation message.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get userPasswordRequired;

  /// Snackbar after creating a user.
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String userCreated(String name);

  /// Status for a locked user.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get userLocked;

  /// Label for a built-in account or group.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get userBuiltin;

  /// Menu action to lock a user.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get userLock;

  /// Menu action to unlock a user.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get userUnlock;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Locked {name}'**
  String userLockedMessage(String name);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Unlocked {name}'**
  String userUnlockedMessage(String name);

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete user {name}?'**
  String userDeleteTitle(String name);

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'The account and its private group are removed. Files it owns stay on disk.'**
  String get userDeleteBody;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String userDeleted(String name);

  /// Label when a user has two-factor sign-in set up.
  ///
  /// In en, this message translates to:
  /// **'Two-factor'**
  String get userTwoFactor;

  /// Groups section title.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsTitle;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'No groups yet. System groups are hidden.'**
  String get groupsEmpty;

  /// Button to create a group.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get groupCreate;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String groupCreated(String name);

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete group {name}?'**
  String groupDeleteTitle(String name);

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Members keep their accounts.'**
  String get groupDeleteBody;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String groupDeleted(String name);

  /// API keys screen title.
  ///
  /// In en, this message translates to:
  /// **'API keys'**
  String get apiKeysTitle;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'No API keys yet.'**
  String get apiKeysEmpty;

  /// Button to create an API key.
  ///
  /// In en, this message translates to:
  /// **'Add API key'**
  String get apiKeyCreate;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Key name'**
  String get apiKeyName;

  /// Field label for the user a key belongs to.
  ///
  /// In en, this message translates to:
  /// **'For user'**
  String get apiKeyUser;

  /// Dialog title after creating a key.
  ///
  /// In en, this message translates to:
  /// **'Copy your API key'**
  String get apiKeyCreatedTitle;

  /// Dialog body after creating a key.
  ///
  /// In en, this message translates to:
  /// **'This is the only time the key is shown. Store it somewhere safe.'**
  String get apiKeyCreatedBody;

  /// Snackbar after copying.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get apiKeyCopied;

  /// Status for a revoked key.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get apiKeyRevoked;

  /// Expiry line.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String apiKeyExpires(String date);

  /// Creation line.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String apiKeyCreatedOn(String date);

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete API key {name}?'**
  String apiKeyDeleteTitle(String name);

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Anything using this key loses access.'**
  String get apiKeyDeleteBody;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String apiKeyDeleted(String name);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Label.
  ///
  /// In en, this message translates to:
  /// **'Hostname'**
  String get networkHostname;

  /// Label.
  ///
  /// In en, this message translates to:
  /// **'Default gateway'**
  String get networkGateway;

  /// Label.
  ///
  /// In en, this message translates to:
  /// **'DNS servers'**
  String get networkDns;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Interfaces'**
  String get networkInterfaces;

  /// Interface status.
  ///
  /// In en, this message translates to:
  /// **'Link up'**
  String get networkLinkUp;

  /// Interface status.
  ///
  /// In en, this message translates to:
  /// **'Link down'**
  String get networkLinkDown;

  /// Label for an interface using DHCP.
  ///
  /// In en, this message translates to:
  /// **'DHCP'**
  String get networkDhcp;

  /// Shown when a value is not set.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get networkNone;

  /// Certificates screen title.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get certificatesTitle;

  /// Empty state.
  ///
  /// In en, this message translates to:
  /// **'No certificates.'**
  String get certificatesEmpty;

  /// Status.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get certificateExpired;

  /// Expiry line.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String certificateValidUntil(String date);

  /// Updates screen title.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updatesTitle;

  /// Current version line.
  ///
  /// In en, this message translates to:
  /// **'Running {version}'**
  String updateCurrent(String version);

  /// Update status.
  ///
  /// In en, this message translates to:
  /// **'{version} is available'**
  String updateAvailable(String version);

  /// Update status.
  ///
  /// In en, this message translates to:
  /// **'TrueNAS is up to date'**
  String get updateNone;

  /// Update status.
  ///
  /// In en, this message translates to:
  /// **'An update is installed. Restart to finish.'**
  String get updateRebootRequired;

  /// Update status.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates: {reason}'**
  String updateCheckFailed(String reason);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Install and restart'**
  String get updateInstall;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Install {version}?'**
  String updateInstallTitle(String version);

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'The server downloads the update, installs it and restarts. It is unavailable while it restarts.'**
  String get updateInstallBody;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Update started. The server restarts when it\'s done.'**
  String get updateStarted;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get updateReleaseNotes;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Boot environments'**
  String get bootEnvsTitle;

  /// Status.
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get bootEnvActive;

  /// Status.
  ///
  /// In en, this message translates to:
  /// **'Used on next boot'**
  String get bootEnvNextBoot;

  /// Status for a protected boot environment.
  ///
  /// In en, this message translates to:
  /// **'Kept'**
  String get bootEnvKept;

  /// Menu action.
  ///
  /// In en, this message translates to:
  /// **'Use on next boot'**
  String get bootEnvActivate;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Boot {name} next time?'**
  String bootEnvActivateTitle(String name);

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'The server uses this version after its next restart.'**
  String get bootEnvActivateBody;

  /// Menu action.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get bootEnvKeep;

  /// Menu action.
  ///
  /// In en, this message translates to:
  /// **'Stop keeping'**
  String get bootEnvUnkeep;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete boot environment {name}?'**
  String bootEnvDeleteTitle(String name);

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'You can\'t go back to this version afterwards.'**
  String get bootEnvDeleteBody;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Boot environment updated'**
  String get bootEnvChanged;

  /// More tab action.
  ///
  /// In en, this message translates to:
  /// **'Restart server'**
  String get powerReboot;

  /// More tab action.
  ///
  /// In en, this message translates to:
  /// **'Shut down server'**
  String get powerShutdown;

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Restart {name}?'**
  String powerRebootTitle(String name);

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Shut down {name}?'**
  String powerShutdownTitle(String name);

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Everything on the server, including shares, apps and VMs, stops until it is back.'**
  String get powerRebootBody;

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Everything on the server stops. You need physical or remote console access to turn it back on.'**
  String get powerShutdownBody;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'{name} is restarting'**
  String powerRebooting(String name);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'{name} is shutting down'**
  String powerShuttingDown(String name);

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Shut down'**
  String get shutDown;

  /// Member count of a group.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No members} =1{1 member} other{{count} members}}'**
  String groupMembers(int count);

  /// Section header in the More tab.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get moreTools;

  /// API explorer screen title.
  ///
  /// In en, this message translates to:
  /// **'API explorer'**
  String get explorerTitle;

  /// Search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search methods'**
  String get explorerSearch;

  /// Shown when the search finds nothing.
  ///
  /// In en, this message translates to:
  /// **'No methods match.'**
  String get explorerNoMatches;

  /// Number of methods in a namespace.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 method} other{{count} methods}}'**
  String explorerMethodCount(int count);

  /// Badge for methods that run as a job.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get explorerJob;

  /// Badge for methods that don't change anything.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get explorerReadOnly;

  /// Badge for methods that work without signing in.
  ///
  /// In en, this message translates to:
  /// **'No sign-in needed'**
  String get explorerNoAuth;

  /// Roles allowed to call the method.
  ///
  /// In en, this message translates to:
  /// **'Roles: {roles}'**
  String explorerRoles(String roles);

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get explorerParameters;

  /// Shown when there are no parameters.
  ///
  /// In en, this message translates to:
  /// **'This method takes no parameters.'**
  String get explorerNoParameters;

  /// Checkbox to include an optional parameter.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get explorerSendParam;

  /// Label for an optional parameter.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get explorerOptional;

  /// Validation message for JSON fields.
  ///
  /// In en, this message translates to:
  /// **'Not valid JSON: {reason}'**
  String explorerInvalidJson(String reason);

  /// Validation message.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get explorerInvalidNumber;

  /// Button that calls the method.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get explorerRun;

  /// Confirmation title before calling a method that may change things.
  ///
  /// In en, this message translates to:
  /// **'Run {method}?'**
  String explorerRunTitle(String method);

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'This method can change settings or data on the server.'**
  String get explorerRunBody;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get explorerResult;

  /// Shown while a job runs.
  ///
  /// In en, this message translates to:
  /// **'Running as job {id}…'**
  String explorerJobRunning(int id);

  /// Section header for the result schema.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get explorerReturns;

  /// Shown for upload/download methods.
  ///
  /// In en, this message translates to:
  /// **'This method transfers a file, which the explorer can\'t do yet.'**
  String get explorerFileTransfer;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get explorerCopied;

  /// Dropdown entry for leaving a value null.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get explorerUnset;

  /// Shell screen title.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get shellTitle;

  /// Shown while the shell starts.
  ///
  /// In en, this message translates to:
  /// **'Opening a shell…'**
  String get shellConnecting;

  /// Shown when the server closes the shell.
  ///
  /// In en, this message translates to:
  /// **'The shell has ended.'**
  String get shellClosed;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Start a new shell'**
  String get shellReconnect;

  /// Key button that sends an interrupt.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+C'**
  String get shellKeyCtrlC;

  /// Key button.
  ///
  /// In en, this message translates to:
  /// **'Esc'**
  String get shellKeyEsc;

  /// Key button.
  ///
  /// In en, this message translates to:
  /// **'Tab'**
  String get shellKeyTab;

  /// Data protection screen title and More tab entry.
  ///
  /// In en, this message translates to:
  /// **'Data protection'**
  String get protectionTitle;

  /// Shown under a section with no tasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet.'**
  String get protectionEmpty;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Periodic snapshots'**
  String get protectionSnapshots;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Replication'**
  String get protectionReplication;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get protectionCloudSync;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'TrueCloud backup'**
  String get protectionCloudBackup;

  /// Section header.
  ///
  /// In en, this message translates to:
  /// **'Rsync'**
  String get protectionRsync;

  /// Task status.
  ///
  /// In en, this message translates to:
  /// **'Not run yet'**
  String get taskNever;

  /// Task status.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get taskWaiting;

  /// Task status.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get taskRunning;

  /// Task status with progress.
  ///
  /// In en, this message translates to:
  /// **'Running · {percent}%'**
  String taskRunningPercent(int percent);

  /// Task status.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get taskSuccess;

  /// Task status.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get taskFailed;

  /// Task status.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get taskHeld;

  /// When the task last ran.
  ///
  /// In en, this message translates to:
  /// **'Last run {date}'**
  String taskLastRun(String date);

  /// Accessibility label for the task enable switch.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get taskEnabled;

  /// Menu action.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get taskRunNow;

  /// Menu action for a running cloud task.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get taskStop;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Started {name}'**
  String taskStarted(String name);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Stopped {name}'**
  String taskStopped(String name);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Enabled {name}'**
  String taskEnabledMessage(String name);

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Disabled {name}'**
  String taskDisabledMessage(String name);

  /// Confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete the task for {name}?'**
  String taskDeleteTitle(String name);

  /// Confirmation body for deleting a snapshot task.
  ///
  /// In en, this message translates to:
  /// **'Snapshots it already took are kept.'**
  String get taskDeleteBody;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Task deleted'**
  String get taskDeleted;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Add snapshot task'**
  String get snapshotTaskCreate;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Added a snapshot task for {name}'**
  String snapshotTaskCreated(String name);

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Dataset'**
  String get snapshotTaskDataset;

  /// Switch label.
  ///
  /// In en, this message translates to:
  /// **'Include child datasets'**
  String get snapshotTaskRecursive;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get snapshotTaskSchedule;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Keep for'**
  String get snapshotTaskKeepFor;

  /// Schedule.
  ///
  /// In en, this message translates to:
  /// **'Every hour'**
  String get scheduleHourly;

  /// Schedule.
  ///
  /// In en, this message translates to:
  /// **'Every day at midnight'**
  String get scheduleDaily;

  /// Schedule.
  ///
  /// In en, this message translates to:
  /// **'Every Sunday at midnight'**
  String get scheduleWeekly;

  /// Schedule that matches no preset.
  ///
  /// In en, this message translates to:
  /// **'Cron: {cron}'**
  String scheduleCustom(String cron);

  /// Detail for recursive tasks.
  ///
  /// In en, this message translates to:
  /// **'with child datasets'**
  String get snapshotTaskRecursiveLabel;

  /// Retention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Keep 1 hour} other{Keep {count} hours}}'**
  String keepHours(int count);

  /// Retention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Keep 1 day} other{Keep {count} days}}'**
  String keepDays(int count);

  /// Retention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Keep 1 week} other{Keep {count} weeks}}'**
  String keepWeeks(int count);

  /// Retention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Keep 1 month} other{Keep {count} months}}'**
  String keepMonths(int count);

  /// Retention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Keep 1 year} other{Keep {count} years}}'**
  String keepYears(int count);

  /// Lifetime unit.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get unitHours;

  /// Lifetime unit.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get unitDays;

  /// Lifetime unit.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get unitWeeks;

  /// Lifetime unit.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get unitMonths;

  /// Lifetime unit.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get unitYears;

  /// Subtitle of the data protection entry in the Storage tab.
  ///
  /// In en, this message translates to:
  /// **'Snapshot tasks, replication and cloud sync'**
  String get protectionSubtitle;

  /// Button that opens the choice of task kinds to add.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get protectionAdd;

  /// Confirmation body for deleting a replication or cloud sync task.
  ///
  /// In en, this message translates to:
  /// **'Data it already copied is kept.'**
  String get taskDeleteBodyCopies;

  /// Snackbar after saving a task.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String taskSaved(String name);

  /// Editor title.
  ///
  /// In en, this message translates to:
  /// **'New replication task'**
  String get replicationNew;

  /// Editor title.
  ///
  /// In en, this message translates to:
  /// **'Edit replication task'**
  String get replicationEdit;

  /// Editor title.
  ///
  /// In en, this message translates to:
  /// **'New cloud sync task'**
  String get cloudSyncNew;

  /// Editor title.
  ///
  /// In en, this message translates to:
  /// **'Edit cloud sync task'**
  String get cloudSyncEdit;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get taskNameLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get directionLabel;

  /// Replication direction.
  ///
  /// In en, this message translates to:
  /// **'Push: send from this server'**
  String get replicationPush;

  /// Replication direction.
  ///
  /// In en, this message translates to:
  /// **'Pull: fetch from another server'**
  String get replicationPull;

  /// Field label for where replication sends to.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get replicationTransport;

  /// Replication transport.
  ///
  /// In en, this message translates to:
  /// **'Another pool on this server'**
  String get transportLocal;

  /// Replication transport.
  ///
  /// In en, this message translates to:
  /// **'Another server over SSH'**
  String get transportSsh;

  /// Replication transport.
  ///
  /// In en, this message translates to:
  /// **'Another server over SSH with netcat'**
  String get transportNetcat;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'SSH connection'**
  String get replicationSshConnection;

  /// Shown when there is no SSH connection to choose.
  ///
  /// In en, this message translates to:
  /// **'No SSH connections yet. Add one under Credentials in the TrueNAS web interface.'**
  String get replicationNoSshConnections;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Source datasets'**
  String get replicationSources;

  /// Helper text.
  ///
  /// In en, this message translates to:
  /// **'Separate several with commas'**
  String get replicationSourcesHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Destination dataset'**
  String get replicationTarget;

  /// Tooltip of the button that opens the dataset list.
  ///
  /// In en, this message translates to:
  /// **'Choose a dataset'**
  String get pickDataset;

  /// Heading above the snapshot task choices.
  ///
  /// In en, this message translates to:
  /// **'Send snapshots taken by'**
  String get replicationSnapshotTasks;

  /// Shown when there are no snapshot tasks to bind.
  ///
  /// In en, this message translates to:
  /// **'No periodic snapshot tasks. Snapshots are matched by name instead.'**
  String get replicationNoSnapshotTasks;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Snapshot name pattern'**
  String get replicationNamingSchema;

  /// Helper text.
  ///
  /// In en, this message translates to:
  /// **'For example auto-%Y-%m-%d_%H-%M'**
  String get replicationNamingSchemaHint;

  /// Shown for tasks that match snapshots by regex.
  ///
  /// In en, this message translates to:
  /// **'Snapshots are matched by the pattern {regex}. Change it in the TrueNAS web interface.'**
  String replicationNameRegex(String regex);

  /// Switch label.
  ///
  /// In en, this message translates to:
  /// **'Run automatically'**
  String get replicationAuto;

  /// Schedule option for replication bound to snapshot tasks.
  ///
  /// In en, this message translates to:
  /// **'Right after the snapshot task'**
  String get replicationAfterSnapshots;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Keep snapshots on the destination'**
  String get replicationRetention;

  /// Retention policy.
  ///
  /// In en, this message translates to:
  /// **'Same as the source'**
  String get retentionSource;

  /// Retention policy.
  ///
  /// In en, this message translates to:
  /// **'For a set time'**
  String get retentionCustom;

  /// Retention policy.
  ///
  /// In en, this message translates to:
  /// **'Forever'**
  String get retentionNone;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get cloudSyncDescription;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Cloud credential'**
  String get cloudSyncCredential;

  /// Shown when there is no cloud credential to choose.
  ///
  /// In en, this message translates to:
  /// **'No cloud credentials yet. Add one under Credentials in the TrueNAS web interface.'**
  String get cloudSyncNoCredentials;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Bucket'**
  String get cloudSyncBucket;

  /// Helper text.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for providers without buckets'**
  String get cloudSyncBucketHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Remote folder'**
  String get cloudSyncFolder;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Local folder'**
  String get cloudSyncPath;

  /// Helper text.
  ///
  /// In en, this message translates to:
  /// **'A folder under /mnt'**
  String get cloudSyncPathHint;

  /// Validation message.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder under /mnt'**
  String get cloudSyncPathInvalid;

  /// Cloud sync direction.
  ///
  /// In en, this message translates to:
  /// **'Push: upload to the cloud'**
  String get cloudSyncPush;

  /// Cloud sync direction.
  ///
  /// In en, this message translates to:
  /// **'Pull: download from the cloud'**
  String get cloudSyncPull;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Transfer mode'**
  String get transferModeLabel;

  /// Transfer mode.
  ///
  /// In en, this message translates to:
  /// **'Copy new and changed files'**
  String get transferCopy;

  /// Transfer mode.
  ///
  /// In en, this message translates to:
  /// **'Mirror, deleting files missing at the source'**
  String get transferSync;

  /// Transfer mode.
  ///
  /// In en, this message translates to:
  /// **'Move, deleting files from the source'**
  String get transferMove;

  /// Tooltip of the button that reveals a hidden password or key.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get showSecret;

  /// Tooltip of the button that hides a password or key.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hideSecret;

  /// Tooltip of the button that empties the search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// Shell key button.
  ///
  /// In en, this message translates to:
  /// **'Arrow up'**
  String get shellKeyUp;

  /// Shell key button.
  ///
  /// In en, this message translates to:
  /// **'Arrow down'**
  String get shellKeyDown;

  /// Shell key button.
  ///
  /// In en, this message translates to:
  /// **'Arrow left'**
  String get shellKeyLeft;

  /// Shell key button.
  ///
  /// In en, this message translates to:
  /// **'Arrow right'**
  String get shellKeyRight;

  /// Snackbar when an app has no container for a shell.
  ///
  /// In en, this message translates to:
  /// **'This app has no running containers to open a shell in.'**
  String get shellNoContainers;

  /// Title of the dialog that picks an app container.
  ///
  /// In en, this message translates to:
  /// **'Open a shell in'**
  String get shellPickContainer;

  /// Editor title.
  ///
  /// In en, this message translates to:
  /// **'New rsync task'**
  String get rsyncNew;

  /// Editor title.
  ///
  /// In en, this message translates to:
  /// **'Edit rsync task'**
  String get rsyncEdit;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Run as user'**
  String get rsyncUser;

  /// Helper text.
  ///
  /// In en, this message translates to:
  /// **'A local user; over SSH without a saved connection, it needs its own SSH key'**
  String get rsyncUserHint;

  /// Rsync direction.
  ///
  /// In en, this message translates to:
  /// **'Push: copy to the remote host'**
  String get rsyncPush;

  /// Rsync direction.
  ///
  /// In en, this message translates to:
  /// **'Pull: copy from the remote host'**
  String get rsyncPull;

  /// Field label for the rsync mode.
  ///
  /// In en, this message translates to:
  /// **'Connect with'**
  String get rsyncMode;

  /// Rsync mode.
  ///
  /// In en, this message translates to:
  /// **'SSH'**
  String get rsyncModeSsh;

  /// Rsync mode.
  ///
  /// In en, this message translates to:
  /// **'Rsync daemon module'**
  String get rsyncModeModule;

  /// Dropdown entry for typing the SSH host by hand.
  ///
  /// In en, this message translates to:
  /// **'Enter a host instead'**
  String get rsyncManualHost;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Remote host'**
  String get rsyncHost;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'SSH port'**
  String get rsyncPort;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Module name'**
  String get rsyncModule;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Remote path'**
  String get rsyncRemotePath;

  /// Switch label.
  ///
  /// In en, this message translates to:
  /// **'Delete files missing at the source'**
  String get rsyncDelete;

  /// Editor title.
  ///
  /// In en, this message translates to:
  /// **'New TrueCloud backup task'**
  String get cloudBackupNew;

  /// Editor title.
  ///
  /// In en, this message translates to:
  /// **'Edit TrueCloud backup task'**
  String get cloudBackupEdit;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Repository password'**
  String get cloudBackupPassword;

  /// Helper text when creating.
  ///
  /// In en, this message translates to:
  /// **'Encrypts the backups. Keep it safe: without it they can\'t be restored.'**
  String get cloudBackupPasswordHint;

  /// Helper text when editing.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the current password'**
  String get cloudBackupPasswordKeep;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Backups to keep'**
  String get cloudBackupKeepLast;

  /// Shown on the dashboard header while the app is connected to the server
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get dashboardConnected;

  /// Helper text under the password field when editing a saved server.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the saved password, or type a new one to replace it.'**
  String get fieldPasswordKeep;

  /// Helper text under the API key field when editing a saved server.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the saved API key, or paste a new one to replace it.'**
  String get fieldApiKeyKeep;

  /// Bottom navigation label for shares; keep it short, the bar is narrow.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get tabSharesShort;

  /// Printed in the terminal when the default shell is missing in an app or container and another one is tried.
  ///
  /// In en, this message translates to:
  /// **'That shell is not in this container. Trying {shell} instead.'**
  String shellFallback(String shell);

  /// Under the title of the server list: how many servers are saved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 server} other{{count} servers}}'**
  String serversCount(int count);

  /// Button in the shell that types the clipboard into the terminal.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get shellPaste;

  /// Shown after the selected terminal text was copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get shellCopied;

  /// Title of the dialog shown when leaving an open server for the server list.
  ///
  /// In en, this message translates to:
  /// **'Disconnect from {name}?'**
  String leaveServerTitle(String name);

  /// Body of the dialog shown when leaving an open server for the server list.
  ///
  /// In en, this message translates to:
  /// **'You will return to your servers and this connection will be closed, along with any shell or other screen open on it.'**
  String get leaveServerBody;

  /// Button that closes the open server and returns to the server list.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get leaveServerConfirm;

  /// Button that keeps the server open.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get leaveServerStay;

  /// Title of the screen with the app's own settings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get settingsTitle;

  /// Settings section for theme and language.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Setting: light, dark or like the device.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Choice that follows the phone's own setting.
  ///
  /// In en, this message translates to:
  /// **'Same as device'**
  String get settingsSystemDefault;

  /// Theme choice.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme choice.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Setting: the language of the app.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Settings section for behaviour.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// Setting: vibration taps.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHaptics;

  /// Explains the haptic feedback setting.
  ///
  /// In en, this message translates to:
  /// **'Small taps when you refresh, switch tabs or confirm'**
  String get settingsHapticsHint;

  /// Setting: confirm before leaving a server or shell.
  ///
  /// In en, this message translates to:
  /// **'Ask before closing'**
  String get settingsConfirmLeave;

  /// Explains the ask-before-closing setting.
  ///
  /// In en, this message translates to:
  /// **'Confirm before leaving an open server or shell'**
  String get settingsConfirmLeaveHint;

  /// Settings section for the terminal.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get settingsShell;

  /// Setting: terminal text size.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get settingsShellFontSize;

  /// Setting: show Esc, Tab, Ctrl+C and arrows under the terminal.
  ///
  /// In en, this message translates to:
  /// **'Extra keys'**
  String get settingsShellKeys;

  /// Explains the extra keys setting.
  ///
  /// In en, this message translates to:
  /// **'Esc, Tab, Ctrl+C and arrows under the terminal'**
  String get settingsShellKeysHint;

  /// Settings section for phone notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Switch in Settings > Notifications.
  ///
  /// In en, this message translates to:
  /// **'Alert notifications'**
  String get settingsAlertNotifications;

  /// Subtitle of the alert notifications switch on iOS.
  ///
  /// In en, this message translates to:
  /// **'Checks your servers in the background and notifies you of new alerts. iOS decides when the check runs, so it can be late, and it stops if you swipe the app away.'**
  String get settingsAlertNotificationsHintIos;

  /// Subtitle of the alert notifications switch on Android.
  ///
  /// In en, this message translates to:
  /// **'Checks your servers in the background about every 15 minutes and notifies you of new alerts.'**
  String get settingsAlertNotificationsHintAndroid;

  /// Settings row: choose which kinds of alert notify.
  ///
  /// In en, this message translates to:
  /// **'Alert types'**
  String get settingsAlertKinds;

  /// Value of the Alert types row: how many kinds are switched off.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{All on} other{{count} off}}'**
  String settingsAlertKindsMuted(int count);

  /// Title of the screen that lists the kinds of alert.
  ///
  /// In en, this message translates to:
  /// **'Alert types'**
  String get alertKindsTitle;

  /// Explains the alert types screen.
  ///
  /// In en, this message translates to:
  /// **'Switch off the types of alert you don\'t want a notification for. They still show in the Alerts list.'**
  String get alertKindsHint;

  /// Empty state of the alert types screen.
  ///
  /// In en, this message translates to:
  /// **'Alert types appear here after the first background check of a server.'**
  String get alertKindsEmpty;

  /// Hint of the search box on the alert types screen.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get alertKindsSearch;

  /// Group for alert types TrueNAS did not sort into a category.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get alertKindsOther;

  /// Alert menu entry: stop notifications for this kind of alert.
  ///
  /// In en, this message translates to:
  /// **'Don\'t notify for this type'**
  String get alertMuteKind;

  /// Alert menu entry: bring notifications for this kind of alert back.
  ///
  /// In en, this message translates to:
  /// **'Notify for this type again'**
  String get alertUnmuteKind;

  /// Snackbar after muting a kind of alert.
  ///
  /// In en, this message translates to:
  /// **'No more notifications for \"{kind}\"'**
  String alertKindMuted(String kind);

  /// Snackbar after un-muting a kind of alert.
  ///
  /// In en, this message translates to:
  /// **'Notifications for \"{kind}\" are back'**
  String alertKindUnmuted(String kind);

  /// Setting: the lowest alert level that sends a notification.
  ///
  /// In en, this message translates to:
  /// **'Notify for'**
  String get settingsAlertLevel;

  /// Choice: notify for critical alerts only.
  ///
  /// In en, this message translates to:
  /// **'Critical alerts'**
  String get settingsAlertLevelCritical;

  /// Choice: notify for warnings and critical alerts.
  ///
  /// In en, this message translates to:
  /// **'Warnings and critical'**
  String get settingsAlertLevelWarning;

  /// Snackbar when the user refused the notification permission.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for this app. Allow them in the phone\'s settings first.'**
  String get settingsAlertPermissionDenied;

  /// Snackbar when scheduling the background alert check failed.
  ///
  /// In en, this message translates to:
  /// **'The phone would not start the background check. Try again in a moment.'**
  String get settingsAlertScheduleFailed;

  /// Name of the Android notification channel for new alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertNotificationChannel;

  /// Description of the Android notification channel.
  ///
  /// In en, this message translates to:
  /// **'New alerts from your TrueNAS servers'**
  String get alertNotificationChannelDescription;

  /// Notification text when several alerts arrived at once.
  ///
  /// In en, this message translates to:
  /// **'{count} new alerts'**
  String alertNotificationMany(int count);

  /// Settings section.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// Switch in Settings > Security.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingsAppLock;

  /// Subtitle of the app lock switch on a phone with face unlock.
  ///
  /// In en, this message translates to:
  /// **'Ask for Face ID or the device passcode when the app opens or comes back from the background.'**
  String get settingsAppLockHintFace;

  /// Subtitle of the app lock switch on a phone with a fingerprint reader.
  ///
  /// In en, this message translates to:
  /// **'Ask for a fingerprint or the device passcode when the app opens or comes back from the background.'**
  String get settingsAppLockHintFingerprint;

  /// Subtitle of the app lock switch when the phone's biometric is not known.
  ///
  /// In en, this message translates to:
  /// **'Ask for biometrics or the device passcode when the app opens or comes back from the background.'**
  String get settingsAppLockHintOther;

  /// Reason shown in the system's Face ID / fingerprint prompt when opening the app.
  ///
  /// In en, this message translates to:
  /// **'Unlock TrueNAS Mobile'**
  String get appLockReason;

  /// Reason shown in the system prompt when turning the app lock on or off in Settings.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you to change the app lock'**
  String get appLockChangeReason;

  /// Title of the lock screen.
  ///
  /// In en, this message translates to:
  /// **'TrueNAS Mobile is locked'**
  String get appLockTitle;

  /// Shown on the lock screen after the prompt was cancelled or failed.
  ///
  /// In en, this message translates to:
  /// **'Not unlocked. Try again.'**
  String get appLockFailed;

  /// Button on the lock screen that opens the system prompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get appLockUnlock;

  /// Row that opens the list of certificates the user chose to trust.
  ///
  /// In en, this message translates to:
  /// **'Trusted certificates'**
  String get settingsCertificates;

  /// Empty list of trusted certificates.
  ///
  /// In en, this message translates to:
  /// **'No certificates are trusted. A self-signed certificate you accept for a server will show up here.'**
  String get settingsCertificatesEmpty;

  /// Button that stops trusting a certificate.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get settingsCertificateForget;

  /// Title of the confirmation.
  ///
  /// In en, this message translates to:
  /// **'Forget the certificate of {name}?'**
  String settingsCertificateForgetTitle(String name);

  /// Body of the confirmation.
  ///
  /// In en, this message translates to:
  /// **'You will be asked whether to trust it again the next time you connect.'**
  String get settingsCertificateForgetBody;

  /// Settings section.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Row with the app version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// Row that opens the licence list.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get settingsLicences;

  /// Row that opens the project page.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get settingsSource;

  /// Title of the dialog shown when leaving a running shell.
  ///
  /// In en, this message translates to:
  /// **'Close the shell?'**
  String get shellLeaveTitle;

  /// Body of the dialog shown when leaving a running shell.
  ///
  /// In en, this message translates to:
  /// **'Anything running in it stops.'**
  String get shellLeaveBody;

  /// Button that closes the shell.
  ///
  /// In en, this message translates to:
  /// **'Close shell'**
  String get shellLeaveConfirm;

  /// Section of the settings with the update options.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get settingsUpdates;

  /// Switch that makes the app look for a newer release when it opens.
  ///
  /// In en, this message translates to:
  /// **'Check on start'**
  String get settingsCheckUpdates;

  /// Explains what the check on start does.
  ///
  /// In en, this message translates to:
  /// **'Looks for a newer release on GitHub when the app opens. Nothing else is sent.'**
  String get settingsCheckUpdatesHint;

  /// Row that opens the update screen and looks for a newer release.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsCheckNow;

  /// Row that opens the list of release notes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get settingsReleaseNotes;

  /// Title of the update screen.
  ///
  /// In en, this message translates to:
  /// **'Software update'**
  String get appUpdateTitle;

  /// Shown while looking for a newer release.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get appUpdateChecking;

  /// Shown when the installed app is the newest release.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get appUpdateUpToDateTitle;

  /// Tells which version is installed and newest.
  ///
  /// In en, this message translates to:
  /// **'TrueNAS Mobile {version} is the newest release.'**
  String appUpdateUpToDateBody(String version);

  /// Shown when GitHub lists no releases.
  ///
  /// In en, this message translates to:
  /// **'No releases have been published yet.'**
  String get appUpdateNoReleases;

  /// Headline on the update screen when a newer release exists.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String appUpdateAvailableTitle(String version);

  /// Says which version is installed.
  ///
  /// In en, this message translates to:
  /// **'You have version {current}.'**
  String appUpdateAvailableBody(String current);

  /// When a release was published.
  ///
  /// In en, this message translates to:
  /// **'Released {date}'**
  String appUpdateReleased(DateTime date);

  /// Android button that downloads the new APK and opens the installer.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get appUpdateDownload;

  /// Button that opens the release on GitHub, where the new version can be downloaded.
  ///
  /// In en, this message translates to:
  /// **'Open release page'**
  String get appUpdateOpenRelease;

  /// Link to the release on GitHub.
  ///
  /// In en, this message translates to:
  /// **'View on GitHub'**
  String get appUpdateViewOnGitHub;

  /// Button that stops the app from offering this release.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get appUpdateSkip;

  /// Shown on a release the user chose to skip.
  ///
  /// In en, this message translates to:
  /// **'You chose to skip this version, so it is not offered when the app opens.'**
  String get appUpdateSkippedNote;

  /// Button that makes a skipped release be offered again.
  ///
  /// In en, this message translates to:
  /// **'Stop skipping'**
  String get appUpdateUnskip;

  /// Button that closes the update prompt without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get appUpdateLater;

  /// Button in the update prompt that opens the update screen.
  ///
  /// In en, this message translates to:
  /// **'View update'**
  String get appUpdateViewUpdate;

  /// Title of the prompt shown when the app opens and a newer release exists.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get appUpdatePromptTitle;

  /// Body of the update prompt.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available. You have {current}.'**
  String appUpdatePromptBody(String version, String current);

  /// Shown while the APK downloads and its size is not known.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get appUpdateDownloading;

  /// Shown while the APK downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String appUpdateDownloadingPercent(int percent);

  /// Shown right after the download, while Android's installer opens.
  ///
  /// In en, this message translates to:
  /// **'Opening the installer…'**
  String get appUpdateInstalling;

  /// Heading above the release notes of the new version.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get appUpdateWhatsNew;

  /// Shown for a release without notes.
  ///
  /// In en, this message translates to:
  /// **'This release has no notes.'**
  String get appUpdateNoNotes;

  /// Row that opens the list of every release's notes.
  ///
  /// In en, this message translates to:
  /// **'All release notes'**
  String get appUpdateAllNotes;

  /// Error when GitHub could not be reached.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates. Check your connection and try again.'**
  String get appUpdateCheckFailed;

  /// Error when GitHub's request limit was hit.
  ///
  /// In en, this message translates to:
  /// **'GitHub is limiting requests from this network. Try again later.'**
  String get appUpdateRateLimited;

  /// Error when the release has no APK for the phone's CPU.
  ///
  /// In en, this message translates to:
  /// **'This release has no APK for your phone. Open the release page to get it.'**
  String get appUpdateErrNoApk;

  /// Error when the APK download failed.
  ///
  /// In en, this message translates to:
  /// **'The download failed. Check your connection and try again.'**
  String get appUpdateErrDownload;

  /// Error when the downloaded APK does not match its checksum.
  ///
  /// In en, this message translates to:
  /// **'The downloaded file is damaged. Try again.'**
  String get appUpdateErrDamaged;

  /// Error when Android's installer could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the installer.'**
  String get appUpdateErrInstall;

  /// Title of the dialog that asks the user to allow installs from this app.
  ///
  /// In en, this message translates to:
  /// **'Allow installing updates'**
  String get appUpdatePermissionTitle;

  /// Explains why Android's settings are opened.
  ///
  /// In en, this message translates to:
  /// **'Android asks for your permission before an app can install updates. Open the settings, allow it for TrueNAS Mobile, then come back and tap Download and install again.'**
  String get appUpdatePermissionBody;

  /// Button that opens Android's page for allowing installs from this app.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get appUpdateOpenSettings;

  /// Headline of the card at the top of the apps list when some apps have newer versions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 app has an update} other{{count} apps have updates}}'**
  String appsUpdatesAvailable(int count);

  /// Button that updates every app that has a newer version.
  ///
  /// In en, this message translates to:
  /// **'Update all'**
  String get appsUpdateAll;

  /// Title of the confirmation before updating every app with an update.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Update 1 app?} other{Update {count} apps?}}'**
  String appsUpdateAllTitle(int count);

  /// Explains what Update all does, above the list of apps.
  ///
  /// In en, this message translates to:
  /// **'TrueNAS updates these apps itself, one after another, and each restarts while it updates. It carries on if you close the app.'**
  String get appsUpdateAllBody;

  /// Reassurance under the Update all progress bar.
  ///
  /// In en, this message translates to:
  /// **'TrueNAS carries on if you leave this screen or close the app.'**
  String get appsUpdateAllLeave;

  /// Progress line while the server runs a bulk action over apps. The action is upgrade, start, stop or restart.
  ///
  /// In en, this message translates to:
  /// **'{action, select, upgrade{Updating} start{Starting} stop{Stopping} restart{Restarting} other{Working}} on the server: {done} of {total} done'**
  String appsBulkRunning(String action, int done, int total);

  /// Progress line when the server does not say how far a bulk action has got.
  ///
  /// In en, this message translates to:
  /// **'{action, select, upgrade{Updating} start{Starting} stop{Stopping} restart{Restarting} other{Working}} {total, plural, =1{1 app} other{{total} apps}} on the server'**
  String appsBulkRunningNoCount(String action, int total);

  /// Snackbar after a bulk action over apps worked for every app.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 app} other{{count} apps}} {action, select, upgrade{updated} start{started} stop{stopped} restart{restarted} other{done}}'**
  String appsBulkDone(int count, String action);

  /// Snackbar when a bulk action over apps failed for some apps.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} apps {action, select, upgrade{updated} start{started} stop{stopped} restart{restarted} other{done}}. {action, select, upgrade{Not updated} start{Not started} stop{Not stopped} restart{Not restarted} other{Failed}}: {failed}'**
  String appsBulkPartial(int done, int total, String failed, String action);

  /// Button that starts picking apps for a bulk action.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get appsSelect;

  /// Button that selects every app.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get appsSelectAll;

  /// Header while picking apps.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String appsSelectedCount(int count);

  /// Bulk action button: update the selected apps.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get appsBulkUpdate;

  /// Confirmation title before stopping the selected apps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Stop 1 app?} other{Stop {count} apps?}}'**
  String appsBulkStopTitle(int count);

  /// Confirmation text before stopping the selected apps.
  ///
  /// In en, this message translates to:
  /// **'They can\'t be reached until they are started again.'**
  String get appsBulkStopBody;

  /// Confirmation title before restarting the selected apps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Restart 1 app?} other{Restart {count} apps?}}'**
  String appsBulkRestartTitle(int count);

  /// Confirmation text before restarting the selected apps.
  ///
  /// In en, this message translates to:
  /// **'They are unavailable for a moment while they restart.'**
  String get appsBulkRestartBody;

  /// Subtitle of the Language row when the language is chosen in the system settings.
  ///
  /// In en, this message translates to:
  /// **'Opens this app\'s language page in your phone\'s settings'**
  String get settingsLanguageSystemHint;

  /// Snackbar when the system language page could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not open your phone\'s settings.'**
  String get settingsLanguageOpenFailed;

  /// Settings section: what the app does when it opens.
  ///
  /// In en, this message translates to:
  /// **'At start'**
  String get settingsStartup;

  /// Setting: the server the app opens by itself at start.
  ///
  /// In en, this message translates to:
  /// **'Default server'**
  String get settingsDefaultServer;

  /// Choice: open no server at start.
  ///
  /// In en, this message translates to:
  /// **'None, show the server list'**
  String get settingsDefaultServerNone;

  /// Label on the server card of the default server.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get serverDefaultBadge;

  /// Setting: show running jobs on the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Live job progress'**
  String get settingsLiveJobs;

  /// Explains the live job progress setting.
  ///
  /// In en, this message translates to:
  /// **'Scrubs, replications and updates on the lock screen and in notifications'**
  String get settingsLiveJobsHint;

  /// Kind of job: a pool scrub.
  ///
  /// In en, this message translates to:
  /// **'Scrub'**
  String get jobKindScrub;

  /// Kind of job: a replication task run.
  ///
  /// In en, this message translates to:
  /// **'Replication'**
  String get jobKindReplication;

  /// Kind of job: applications being updated.
  ///
  /// In en, this message translates to:
  /// **'App update'**
  String get jobKindAppUpdate;

  /// Kind of job: a cloud sync task run.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get jobKindCloudSync;

  /// Kind of job: a cloud backup task run.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get jobKindCloudBackup;

  /// Kind of job: an rsync task run.
  ///
  /// In en, this message translates to:
  /// **'Rsync task'**
  String get jobKindRsync;

  /// Kind of job: the TrueNAS system being updated.
  ///
  /// In en, this message translates to:
  /// **'System update'**
  String get jobKindSystemUpdate;

  /// Lock screen text when the app lost touch with the server and no longer updates the progress.
  ///
  /// In en, this message translates to:
  /// **'Not updating, open the app'**
  String get jobsStale;

  /// Shown in the app under running jobs when the server cannot be reached.
  ///
  /// In en, this message translates to:
  /// **'Connection lost, progress may be out of date'**
  String get jobsConnectionLost;

  /// Under the running jobs when there are more than shown.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String jobsMoreCount(int count);

  /// Android notification channel name for running jobs.
  ///
  /// In en, this message translates to:
  /// **'Job progress'**
  String get jobsChannelName;

  /// Android notification channel description.
  ///
  /// In en, this message translates to:
  /// **'Progress of scrubs, replications and updates'**
  String get jobsChannelDescription;

  /// Title shown when the saved servers could not be read from secure storage.
  ///
  /// In en, this message translates to:
  /// **'Can\'t read your saved servers'**
  String get serversLoadErrorTitle;

  /// Explains that a failed read deleted nothing and offers retry or clearing.
  ///
  /// In en, this message translates to:
  /// **'Nothing was deleted. The phone\'s secure storage did not answer. Try again; if it keeps failing, clear the list and add your servers again.'**
  String get serversLoadErrorBody;

  /// Button that clears the saved servers when they cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Clear saved servers'**
  String get serversClearAction;

  /// Title of the clear-all-servers confirmation.
  ///
  /// In en, this message translates to:
  /// **'Clear saved servers?'**
  String get serversClearTitle;

  /// Body of the clear-all-servers confirmation.
  ///
  /// In en, this message translates to:
  /// **'Every server saved in this app is removed from it. Nothing changes on the servers themselves.'**
  String get serversClearBody;

  /// Confirm button of the clear-all-servers dialog.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get serversClearConfirm;

  /// Snackbar when saving a server to secure storage failed.
  ///
  /// In en, this message translates to:
  /// **'The server could not be saved: {error}'**
  String serverSaveFailed(String error);

  /// Shown under the live job progress setting on iOS when the widget extension is missing.
  ///
  /// In en, this message translates to:
  /// **'This copy of the app has no lock screen extension (the sideloading tool removed it), so jobs show in the app only'**
  String get settingsLiveJobsNoExtension;

  /// Shown under the live job progress setting when the user turned Live Activities off.
  ///
  /// In en, this message translates to:
  /// **'Live Activities are turned off for this app in iOS Settings'**
  String get settingsLiveJobsDisabled;

  /// Tooltip of the button that hides the running jobs card.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get jobsDismiss;

  /// Tooltip of the progress gauge in the app bar.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 job running} other{{count} jobs running}}'**
  String jobsRunningCount(int count);

  /// Subtitle of the snapshots row on a dataset.
  ///
  /// In en, this message translates to:
  /// **'Browse, roll back and clone'**
  String get snapshotsBrowse;

  /// Hint of the snapshot search field.
  ///
  /// In en, this message translates to:
  /// **'Search snapshots'**
  String get snapshotsSearch;

  /// Shown when the search matches no snapshot.
  ///
  /// In en, this message translates to:
  /// **'No snapshots match'**
  String get snapshotsNoMatch;

  /// Count and total size of a dataset's snapshots.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 snapshot} other{{count} snapshots}} · {used} used'**
  String snapshotsSummary(int count, String used);

  /// Tooltip and title of the snapshot sort choice.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get snapshotSort;

  /// Sort option.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get snapshotSortNewest;

  /// Sort option.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get snapshotSortOldest;

  /// Sort option.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get snapshotSortName;

  /// Sort option.
  ///
  /// In en, this message translates to:
  /// **'Size (used)'**
  String get snapshotSortSize;

  /// Warning above the list of snapshots a rollback destroys.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This newer snapshot will be destroyed:} other{These {count} newer snapshots will be destroyed:}}'**
  String snapshotRollbackNewer(int count);

  /// Last line of a shortened list.
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String snapshotRollbackMore(int count);

  /// Checkbox in the rollback dialog.
  ///
  /// In en, this message translates to:
  /// **'Also destroy clones of those snapshots'**
  String get snapshotRollbackClones;

  /// Checkbox in the rollback dialog.
  ///
  /// In en, this message translates to:
  /// **'Force unmount'**
  String get snapshotRollbackForce;

  /// Menu item and button that clones a snapshot.
  ///
  /// In en, this message translates to:
  /// **'Clone'**
  String get snapshotClone;

  /// Title of the clone dialog.
  ///
  /// In en, this message translates to:
  /// **'Clone {name}'**
  String snapshotCloneTitle(String name);

  /// Body of the clone dialog.
  ///
  /// In en, this message translates to:
  /// **'Makes a new dataset that starts as a copy of this snapshot. It takes no space until it changes.'**
  String get snapshotCloneBody;

  /// Label of the clone target field.
  ///
  /// In en, this message translates to:
  /// **'New dataset'**
  String get snapshotCloneTarget;

  /// Validation message of the clone target.
  ///
  /// In en, this message translates to:
  /// **'Use a path inside {pool}, like {pool}/copy'**
  String snapshotCloneInvalid(String pool);

  /// Snackbar after cloning.
  ///
  /// In en, this message translates to:
  /// **'Created {name}'**
  String snapshotCloned(String name);

  /// Title of the usage history screen and the link to it on the dashboard.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// Time range segment: the last hour.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get historyRangeHour;

  /// Time range segment: the last day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get historyRangeDay;

  /// Time range segment: the last week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get historyRangeWeek;

  /// Time range segment: the last month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get historyRangeMonth;

  /// Title of the CPU temperature history chart.
  ///
  /// In en, this message translates to:
  /// **'CPU temperature'**
  String get historyCpuTemperature;

  /// Label of the network interface picker on the history screen.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get historyInterface;

  /// Label of the disk picker on the history screen.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get historyDisk;

  /// Title of the disk temperature history chart.
  ///
  /// In en, this message translates to:
  /// **'Disk temperature'**
  String get historyDiskTemperature;

  /// Title of the ZFS ARC size history chart.
  ///
  /// In en, this message translates to:
  /// **'ZFS cache (ARC)'**
  String get historyArc;

  /// Shown in a chart that has no samples in the chosen range.
  ///
  /// In en, this message translates to:
  /// **'No data for this period yet.'**
  String get historyNoData;

  /// Summary under a history chart line.
  ///
  /// In en, this message translates to:
  /// **'Average {average} · peak {peak}'**
  String historyStats(String average, String peak);

  /// Shown when the server does not offer reporting methods.
  ///
  /// In en, this message translates to:
  /// **'This server has no history data.'**
  String get historyUnavailable;

  /// Shown in a history chart whose data request failed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this chart.'**
  String get historyChartFailed;

  /// Title of the pool health home screen widget.
  ///
  /// In en, this message translates to:
  /// **'Pools'**
  String get homeWidgetPools;

  /// Title of the CPU and memory home screen widget.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get homeWidgetSystem;

  /// Title of the alerts home screen widget.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get homeWidgetAlerts;

  /// Label of the processor gauge in the home screen widget.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get homeWidgetCpu;

  /// Label of the memory gauge in the home screen widget.
  ///
  /// In en, this message translates to:
  /// **'RAM'**
  String get homeWidgetMemory;

  /// Shown before the time a home screen widget last got data.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get homeWidgetUpdated;

  /// Shown in a home screen widget when the last check could not reach the server.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server'**
  String get homeWidgetUnreachable;

  /// Shown in a home screen widget when no server is saved.
  ///
  /// In en, this message translates to:
  /// **'Open TrueNAS Mobile to set up'**
  String get homeWidgetSetup;

  /// Shown in a home screen widget before it has data for the server.
  ///
  /// In en, this message translates to:
  /// **'No data yet. Open the app.'**
  String get homeWidgetNoData;

  /// Pool widget summary when the server has no pools.
  ///
  /// In en, this message translates to:
  /// **'No pools'**
  String get homeWidgetNoPools;

  /// Pool widget summary when every pool is healthy.
  ///
  /// In en, this message translates to:
  /// **'All pools healthy'**
  String get homeWidgetPoolsOk;

  /// Pool widget summary when some pools are not healthy.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 pool needs attention} other{{count} pools need attention}}'**
  String homeWidgetPoolsAttention(int count);

  /// Alerts widget summary when nothing is active.
  ///
  /// In en, this message translates to:
  /// **'No active alerts'**
  String get homeWidgetAlertsNone;

  /// Alerts widget summary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 active alert} other{{count} active alerts}}'**
  String homeWidgetAlertsCount(int count);

  /// Activity widget summary when no app has an update.
  ///
  /// In en, this message translates to:
  /// **'All apps are up to date'**
  String get homeWidgetAppsNone;

  /// Activity widget summary when apps have updates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 app has an update} other{{count} apps have updates}}'**
  String homeWidgetAppsUpdates(int count);

  /// Activity widget text when no scrub or cloud sync is running.
  ///
  /// In en, this message translates to:
  /// **'No scrub or cloud sync running'**
  String get homeWidgetIdle;

  /// Memory in use out of the total, in the system widget.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total}'**
  String homeWidgetMemoryText(String used, String total);

  /// Switch in Settings for refreshing the widgets in the background.
  ///
  /// In en, this message translates to:
  /// **'Home screen widgets'**
  String get settingsHomeWidgets;

  /// Hint under the home screen widgets switch.
  ///
  /// In en, this message translates to:
  /// **'Keep widgets up to date in the background, about every 15 minutes. They also update while a server is open. Add them from your home screen; the phone decides when a refresh really runs.'**
  String get settingsHomeWidgetsHint;

  /// Switch in Settings (iOS) that lets Siri and the Shortcuts app act on the saved servers.
  ///
  /// In en, this message translates to:
  /// **'Siri and Shortcuts'**
  String get settingsShortcuts;

  /// Hint under the Siri and Shortcuts switch.
  ///
  /// In en, this message translates to:
  /// **'Let Siri and the Shortcuts app restart an app or run a cloud sync on your servers, without opening this app. They sign in with the details this app keeps for the widgets. Accounts with two-factor authentication can\'t be used.'**
  String get settingsShortcutsHint;

  /// Button that installs a system update without restarting.
  ///
  /// In en, this message translates to:
  /// **'Install, restart later'**
  String get updateInstallLater;

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'The server downloads and installs the update but keeps running. It takes effect the next time the server restarts.'**
  String get updateInstallLaterBody;

  /// Snackbar.
  ///
  /// In en, this message translates to:
  /// **'Update started. Restart the server to finish it.'**
  String get updateStartedNoRestart;

  /// Button shown when an update is installed and waits for a restart.
  ///
  /// In en, this message translates to:
  /// **'Restart now'**
  String get updateRestartNow;

  /// Expandable list of what an update changes.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get updateChangelog;

  /// Size of a system update download.
  ///
  /// In en, this message translates to:
  /// **'Download size: {size}'**
  String updateDownloadSize(String size);

  /// Settings row that opens the error log.
  ///
  /// In en, this message translates to:
  /// **'Error log'**
  String get settingsErrorLog;

  /// Title of the error log screen.
  ///
  /// In en, this message translates to:
  /// **'Error log'**
  String get logTitle;

  /// Note at the top of the error log.
  ///
  /// In en, this message translates to:
  /// **'Errors and failed connections are kept here, on this phone only. Passwords and keys are left out, but server addresses are not: look through the log before you share it.'**
  String get logNote;

  /// Empty state title of the error log.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded'**
  String get logEmptyTitle;

  /// Empty state text of the error log.
  ///
  /// In en, this message translates to:
  /// **'Errors the app runs into show up here.'**
  String get logEmptyBody;

  /// Tooltip of the button that shares the log.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get logShare;

  /// Tooltip and title of the action that empties the log.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get logClear;

  /// Confirmation body.
  ///
  /// In en, this message translates to:
  /// **'This removes every entry from the log on this phone.'**
  String get logClearBody;

  /// Confirmation button that empties the log.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get logClearConfirm;

  /// Snackbar after the log was copied.
  ///
  /// In en, this message translates to:
  /// **'Log copied'**
  String get logCopied;

  /// Snackbar when the share sheet failed.
  ///
  /// In en, this message translates to:
  /// **'Could not share the log'**
  String get logShareFailed;

  /// Label above the stack trace of a log entry.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get logDetails;

  /// Button and menu entry that shows an app container's log.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get appLogsTitle;

  /// Title of the dialog that picks which app container's log to show.
  ///
  /// In en, this message translates to:
  /// **'Show the log of'**
  String get appLogsPickContainer;

  /// Snackbar when an app has no container for a log.
  ///
  /// In en, this message translates to:
  /// **'This app has no containers to show a log for.'**
  String get appLogsNoContainers;

  /// Shown when the container has not printed anything.
  ///
  /// In en, this message translates to:
  /// **'No output yet.'**
  String get appLogsEmpty;

  /// Shown when the log filter matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No lines match.'**
  String get appLogsNoMatches;

  /// Tooltip and hint of the log filter.
  ///
  /// In en, this message translates to:
  /// **'Filter lines'**
  String get appLogsFilter;

  /// Tooltip of the button that scrolls the log to its end and follows it.
  ///
  /// In en, this message translates to:
  /// **'Jump to the latest line'**
  String get appLogsFollow;

  /// Menu entry that empties the log on screen.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get appLogsClear;

  /// Menu entry: how many of the latest log lines to load first.
  ///
  /// In en, this message translates to:
  /// **'Last {count} lines'**
  String appLogsLastLines(int count);
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
      <String>['en', 'hu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hu':
      return AppLocalizationsHu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
