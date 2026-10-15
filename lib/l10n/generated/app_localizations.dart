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

  /// Note at the bottom of the server overview.
  ///
  /// In en, this message translates to:
  /// **'More management screens are coming in the next milestones.'**
  String get serverOverviewNote;

  /// Shown when the user cancels a certificate or 2FA prompt.
  ///
  /// In en, this message translates to:
  /// **'Connection cancelled.'**
  String get errorCancelled;
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
