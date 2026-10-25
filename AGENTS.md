# Agent notes

Guidance for coding agents (and people) working on this repository. The
README covers what the app does; this file covers how to work on it.

## Setup and checks

- Flutter **3.47.7** (pinned in `.github/workflows/*.yml`). If the machine has
  no Flutter, download the stable Linux tarball from
  `storage.googleapis.com/flutter_infra_release/releases/stable/linux/`.
- Before pushing, run what CI runs:
  ```sh
  flutter pub get
  dart format lib test        # CI fails on unformatted code
  flutter analyze
  flutter test
  ```
- README screenshots are goldens, skipped by default:
  `SCREENSHOTS=1 flutter test test/screenshots --update-goldens`.
  The test renderer cannot run the liquid glass shaders, so the iOS glass
  chrome does not render faithfully there.
- Releases: pushing a `v*` tag runs `release.yml` (APKs per ABI, AAB,
  unsigned IPA). Bump `version:` in `pubspec.yaml` (name and build number)
  first.

## Layout

- `lib/core/api/`: JSON-RPC client, connection, auth, one `*Api` class per
  area. No Flutter imports here.
- `lib/core/session/truenas_session.dart`: a signed-in server. Screens get
  the `TrueNasSession` passed in; its `client` survives reconnects.
- `lib/features/<area>/`: screens and tabs.
- `lib/shared/`: theme (`theme.dart`, `AppPalette`), building blocks
  (`ui.dart`, `widgets.dart`), glass chrome (`glass.dart`, the only file that
  imports `liquid_glass_widgets`).
- `lib/l10n/`: ARB files, English first (`app_en.arb`), Hungarian
  (`app_hu.arb`). Every user-facing string goes in both; generated code is
  committed in `lib/l10n/generated`.
- `test/support/fake_truenas_server.dart`: a fake middleware (HTTP, API
  WebSocket, shell WebSocket) that most tests run against. Extend it rather
  than mocking. Widget tests that use real sockets need
  `HttpOverrides.global = null`.

## TrueNAS API facts

- Only the JSON-RPC 2.0 WebSocket at `/api/<version>` is used. REST is gone
  in TrueNAS 26. `GET /api/versions` lists versions; pick the newest the app
  supports. Minimum server: 25.04.
- Gate features on `core.get_methods` (`MethodCatalog`), not on version
  strings. Known splits: `zfs.snapshot` (25.04) vs `pool.snapshot` (25.10+);
  `service.start/stop/restart` (25.04) vs the `service.control` job (25.10+);
  `virt.instance.*` (25.04/25.10) vs `container.*` (26+);
  `update.check_available/update.update` (25.04) vs
  `update.status/update.run` (25.10+); SMB `ro` vs `readonly`.
- 25.04 `group.query` cannot `order_by` name; sort client side.
- Login is tied to the socket. Phones drop sockets in the background, so
  `ReconnectingJsonRpcClient` reconnects and signs in again; event
  subscriptions renew on its `reconnected` stream.
- Shell: `auth.generate_token [300, {}, true, true]`, then the WebSocket at
  **`/websocket/shell/`** (the nginx path; `/_shell` is internal to the NAS
  and fails from outside, e.g. behind a reverse proxy). Send
  `{token, options}`, wait for `{msg: connected, id}`, then binary frames
  both ways; resize with `core.resize_shell(id, cols, rows)`.
- Users often run the NAS behind a reverse proxy (e.g. Nginx Proxy Manager)
  on 443, so never assume the NAS's own port or paths beyond what its nginx
  serves.

## Conventions

- One branded design with platform-adaptive controls (`isCupertino`), not
  separate Material and Cupertino UIs. iOS gets liquid glass chrome.
- On iOS the chrome is `liquid_glass_widgets`, used through its own widgets
  rather than our look-alikes. Read `.claude/skills/liquid-glass-widgets/SKILL.md`
  (the package's own guide, copied from its repo) before touching glass; its
  rules apply (public import only, no glass inside glass, `GlassTabBar.bottom`,
  `GlassDialog`, `GlassSwitch`, ...). `glass.dart` is still the only file that
  imports the package, and the adaptive wrappers below pick the glass widget on
  iOS and the Material one elsewhere.
- Dialogs, choices and "more" menus go through `lib/shared/dialogs.dart`
  (`AppDialog` with `showAppDialog`, `showAppChoice`, `AppPopupMenu`), never
  `AlertDialog`, `showDialog`, `showModalBottomSheet` or `PopupMenuButton`
  directly. `dialogAction` (same file) makes the buttons, never a bare
  `TextButton`/`FilledButton`. On iOS an `AppDialog` is a `GlassAlert` and a
  choice a glass sheet (both in `glass.dart`), a menu the package's
  `GlassMenu`. The alert and the sheet are built on the package's `GlassCard`
  rather than its `GlassDialog` and `showGlassActionSheet`, because those
  cannot be restyled and looked wrong on a phone: the alert's buttons are
  see-through with a coloured glow and a small fixed radius, the sheet is 65%
  see-through and its text has no `Material` to sit on (yellow underlines). So
  ours have a mostly opaque fill over the glass (`_GlassPanel`), a 34 radius,
  and solid capsule buttons (the main one in the accent colour, the rest
  grey, a destructive label red), 1 to 3 per alert. A route has no `Material`,
  so anything that draws text on its own (a sheet) wraps itself in one.
  Keep the glass itself plain (no tint or rim of our own). The two places
  that do set glass colour on purpose: the panel's fill, and the tab bar,
  which is tinted with the page colour because the package's own 24% white
  wash made it a light slab on a dark theme. The one other colour on the tab
  bar is the selected tab's icon and label in the accent colour; the package
  draws a selected tab a second time, 15% larger and heavier, which clipped
  the "D" of Dashboard, so `glass.dart` sets `magnification: 1` and equal
  label weights, and the tab labels stay short ("Home").
- Switches, sliders and segmented controls are `AppSwitch`/`AppSwitchTile`,
  `AppSlider` and `AppSegments` (in `ui.dart`): `GlassSwitch`, `GlassSlider`
  and `GlassSegmentedControl` on iOS (the segments are 58 high so an icon and
  its label fit). Pass `inGlass: true` to `AppSegments` in a dialog (glass
  inside glass distorts). Not ported yet: the scaffolds and app bars (still
  `Scaffold`/`AppBar` with our own `GlassTopEdge` and `ChromeInsets`, instead
  of `GlassScaffold`/`GlassAppBar`), buttons, text fields and snackbars (a
  `GlassToast` needs a live context and would sit over the tab bar).
- Haptics go through `lib/shared/haptics.dart` (switched off by
  `Haptics.enabled`, which the settings notifier keeps in step). Use
  `AppRefreshIndicator`, `AppSwitch` and `AppSwitchTile` (in `ui.dart`)
  instead of the bare Material widgets so pull to refresh and switches tick;
  the Material switch makes no haptic of its own, even in its iOS look.
- App settings (theme, language, haptics, leave warnings, shell font and
  keys) live in `lib/core/settings/` and are read with
  `ref.watch(settingsProvider)`; `main.dart` loads them before `runApp`.
  Add a setting to `AppSettings` (with a default, and a `fromJson` that
  tolerates old or damaged data), a row in
  `lib/features/settings/settings_screen.dart` and both ARB files. The shell
  screen reads them, so widget tests that pump it need a `ProviderScope`.
- The app opens a default server by itself at start (`OpenDefaultServer`,
  on only when `main` turns `openDefaultServerProvider` on): the one chosen in
  settings (`defaultServerId`), a single saved server when nothing was chosen,
  none when `''` was. See `defaultServer` in `lib/core/instances/`. Settings
  are also one tap away inside a server (gear in its app bar).
- Language is chosen on the phone's own page for the app where there is one:
  iOS Settings, and "App languages" on Android 13+ (`locales_config.xml`,
  `android:localeConfig`, `Info.plist` `CFBundleLocalizations`). There the
  settings row only opens that page (`SystemLanguage`,
  `systemLanguagePageProvider`) and the stored `language` is ignored. Android
  12 and older, and tests, keep the in-app picker. A new language goes in the
  ARB files, `locales_config.xml` and `Info.plist`.
- Live job progress (`lib/core/jobs/`, `lib/features/jobs/`): `JobTracker`
  follows scrubs, replications, app/system updates and cloud/rsync tasks
  (`JobKind.ofMethod`; `core.bulk` counts as the method it runs, which is how
  "update all apps" looks) from the `core.get_jobs` events plus a 15 s
  `core.get_jobs` poll while one runs (the poll also reconnects a dropped
  socket and tells stale from live). `JobActivitySync` mirrors them onto
  `LiveProgress` (method channel `hu.adrian.truenasmobile/live_progress`):
  ActivityKit on iOS (`ios/Runner/LiveProgressPlugin.swift`, drawn by the
  `JobActivityWidget` extension, whose `JobActivityAttributes.swift` in
  `ios/Shared` is compiled into both targets) and a notification on Android
  (`LiveProgressPlugin.kt`, a promoted ongoing progress notification on
  Android 16). `JobMonitor` ties them to one open server, `ServerScreen` owns
  it. The in-app card (`JobProgressBanner`) has a close button (hides the jobs
  it showed, not later ones); `JobGaugeButton` is the animated ring in the
  app bar actions. `LiveProgress.support()` (`LiveSupport`) tells a missing
  `JobActivityWidget.appex` (sideloader stripped it: the Dynamic Island is
  empty) from Live Activities switched off; no activity starts without the
  extension, Settings explains, and `ci.yml` checks the unsigned IPA embeds it. There is no push server: the activity is refreshed every 30 s while the
  app runs and goes stale (iOS `staleDate`) or says "not updating" when it
  stops. The widget extension is in `Runner.xcodeproj` by hand (no Xcode here):
  keep "Embed Foundation Extensions" before "Thin Binary" in the Runner phases,
  or the build has a dependency cycle. Setting `liveJobs`.
- App lock (`lib/core/security/biometric_auth.dart`, `lib/features/lock/`):
  setting `appLock`, off by default, offered in Settings > Security only when
  `BiometricAuth.isAvailable` (a biometric or a passcode is set). `AppLockGate`
  sits in `MaterialApp.builder`, above the navigator, and locks at start and on
  `hidden`/`paused`; `inactive` only shows the cover so the app switcher
  snapshot is blank. Changing the setting asks the phone first. `local_auth`
  needs `FlutterFragmentActivity`, an AppCompat launch theme and `USE_BIOMETRIC`
  on Android and `NSFaceIDUsageDescription` on iOS (all set). Tests use
  `FakeBiometricAuth`; the default provider is `NoBiometricAuth`, `main`
  overrides it. The lock screen is the app icon (`assets/app_icon.png`) on the
  page colour, in the same spot as the launch screens (iOS `LaunchScreen`
  with the `LaunchBackground` colour set, Android `launch_background` with
  `colors.xml`, both light and dark), and a cold start waits
  `lockPromptDelayProvider` before the phone's prompt so the launch screen
  (white before) is never what sits behind Face ID. If the page colours in
  `AppPalette` change, change those too.
- Alert notifications (`lib/core/notifications/`): setting `alertNotifications`
  (off by default) and `alertLevel` (critical or warning and up), under
  Settings > Notifications. There is no push server, so the phone's own
  scheduler (Android WorkManager, iOS BGAppRefreshTask, both through
  `workmanager`) runs `alertCallbackDispatcher` about every 15 minutes in a
  headless isolate, which reads the settings and servers from secure storage
  and runs `AlertWatcher`: sign in quietly (a server that needs a certificate
  prompt or a 2FA code is skipped), `alert.list`, notify once per new active
  alert at or above the level through `flutter_local_notifications`. Seen ids
  are kept per server in `alertwatch.v1`; a server seen for the first time, and
  the moment the setting is turned on, only record (old alerts are not news).
  iOS decides when it really runs (and not after the app is swiped away), so
  never promise timing. `SecureKeyValueStore` uses Keychain `first_unlock` so
  the check can read the servers while the phone is locked. Native bits: iOS
  `UIBackgroundModes` fetch, `BGTaskSchedulerPermittedIdentifiers`, and
  `AppDelegate` (`setPluginRegistrantCallback`, `registerLaunchHandlers`, needed
  with the scene lifecycle, and `registerPeriodicTask(withIdentifier:)` for the
  alert task: iOS only takes a BGTask handler registered before launch ends, a
  later `BGTaskScheduler.register` (what Dart's `registerPeriodicTask` does the
  first time) raises an exception that kills the app, so the id in `AppDelegate`,
  `Info.plist` and `_taskName` must match); `turnOn` never throws, it returns
  an `AlertTurnOn`; Android `POST_NOTIFICATIONS`, core library
  desugaring, and the `ic_stat_alert` icon kept by `res/raw/keep.xml`. Tests
  fake the phone with `FakeAlertNotifier`/`FakeBackgroundScheduler`
  (`test/support/alert_fakes.dart`) and the service provider is off unless
  `main` overrides it.
- Alert types can be muted (`mutedAlertKinds`, the alert's `klass`, global not
  per server). `AlertWatcher` still records muted alerts as seen, so
  unmuting never replays old ones. The list for Settings > Notifications >
  Alert types is `AlertKindCatalog` (`alertkinds.v1`), filled by each check
  from `alert.list_categories` (titles and categories, optional on a server)
  and from the alerts seen; muting also works from the menu on an alert in the
  Alerts tab. The live job progress switch (`liveJobs`) sits in the same
  Notifications section.
- Apps tab bulk actions hand the work to the server as one `core.bulk` job
  (what the web UI's "Update All" does), so it carries on when the app is
  closed: "Update all", or Select, tick apps, then Update, Start, Stop or
  Restart (`app.upgrade/start/stop/redeploy`, `AppBulkAction`). The tab polls
  the job (`AppBulkRun`, found again on open via
  `WorkloadsApi.activeBulkRun`); its id is `AppBulkRun.jobId`. Gated on
  `core.bulk`. Tests: `FakeTrueNasServer.holdBulk` keeps a job running.
- Home screen widgets (`lib/core/widgets/`, setting `homeWidgets`, on by
  default): pool health, CPU and memory, active alerts, activity (apps with updates, running scrubs and cloud syncs). `serverWidgetData`
  turns pools, alerts and one `reporting.realtime` sample into JSON with the
  text already localized (plurals worked out in Dart, so Swift and Kotlin only
  draw). `HomeWidgetPublisher` merges it into one document (`snapshot.v1`:
  `labels`, `defaultId`, `servers`) through the `home_widget` plugin, which also
  works in the background check's headless engine (the App Group
  `group.hu.adrian.truenasmobile` on iOS, the `HomeWidgetPreferences` file on
  Android); it keeps what it knew of a server it could not reach (marked
  `unreachable`) and drops removed servers. `HomeWidgetListSync` (wraps the first screen in `app.dart`) publishes the saved server list from app start and on every list or setting change, so a widget's server picker is never empty before a server was opened. Two writers of the data: `HomeWidgetSync` in
  `ServerScreen` (on open, every minute, on resume and pause) and the
  background alert check (`AlertWatcher.check(widgets:)`, same visit, same
  session). That check now also runs for widgets: `runBackgroundAlertCheck`
  does something when alert notifications are on or the setting is on and
  `HomeWidgetsBridge.hasWidgets()` (a widget is on a home screen);
  `AlertNotificationService.resume` schedules on the same condition and
  `turnOff(keepForWidgets:)` leaves the schedule alone. iOS: widgets are in the
  `JobActivityWidget` extension (`HomeWidgets.swift`, `HomeWidgetViews.swift`,
  `HomeWidgetData.swift`), `AppIntentConfiguration` with a server picker, so
  iOS 17+ only (`if #available` in the bundle); both targets have an App Group
  entitlement (`Runner.entitlements`, `JobActivityWidget.entitlements`, set in
  the hand-edited `project.pbxproj`). The widget kinds (`TrueNASPools`,
  `TrueNASSystem`, `TrueNASAlerts`, `TrueNASActivity`) must match `_iosKinds` in
  `home_widgets.dart`; the Android providers (`HomeWidgets.kt`,
  `PoolsWidgetProvider` and friends, `WidgetConfigActivity` for the server
  choice) must match `_androidProviders`. Android uses plain `RemoteViews`
  layouts (`res/layout/widget_*.xml`): a progress bar cannot be tinted in a
  RemoteViews below Android 12, so each bar exists once per colour and the
  provider shows one. Widget gallery names are in `res/values*/widget_strings.xml`
  and, on iOS, inline in `HomeWidgets.swift` (the extension has no string
  files). Tests: `FakeHomeWidgets` in `test/support/home_widget_fakes.dart`.
  **iOS widgets fetch their own data** (`WidgetFetch.swift`): the phone rarely
  runs the app's BGAppRefreshTask, and a widget that only shows what the app
  saved went stale, and after one failed background run said "can't reach" for
  good. So each `timeline` call (every 15 min, 5 after a failure; skipped when
  the data is under a minute old, since the three widgets reload together)
  signs in over its own WebSocket (`/api/<lastApiVersion|current>`,
  `auth.login_ex`, `pool.query`, `alert.list`, one `reporting.realtime`
  sample, system trust plus the pinned fingerprint), shapes the result like
  `serverWidgetData` (`WidgetShape`; keep the two in step, and the plural
  templates `poolsAttentionMany` etc. in `homeWidgetLabels`), merges it into
  `snapshot.v1` and keeps the old numbers when the server is down (footer: "Can't
  reach the server · 14:02"). The sign-in details reach the extension through
  `HomeWidgetsBridge.writeCredentials` ->
  `WidgetCredentialsPlugin.swift` -> a Keychain item in the shared group
  `$(AppIdentifierPrefix)hu.adrian.truenasmobile.shared` (`Shared/WidgetKeychain.swift`,
  compiled into both targets; `keychain-access-groups` in both entitlements,
  the app's own group listed FIRST so flutter_secure_storage's default group,
  and with it the saved servers, does not change; `AppIdentifierPrefix` in both
  Info.plists). Never put the secret in the App Group's plain preferences.
  Written on every `publish` (deduplicated), removed when the widgets are
  switched off or the last server is deleted. A 2FA account cannot sign in
  there. Without the Keychain group (re-signed install) the widgets fall back
  to what the app saved. **Activity widget** (`TrueNASActivity` / `ActivityWidgetProvider`, small
  and medium on iOS): `apps` (`{updates, summary}`, from `app.query`'s
  `upgrade_available`; `_apps` in `home_widget_data.dart`, `WidgetShape.apps`)
  and `jobs.items` (`{kind, title, percent, detail}` for scrubs, cloud syncs
  and cloud backups, at most 3; from `core.get_jobs` filtered to
  WAITING/RUNNING; `_jobItems`, `WidgetShape.jobs`). Either is null when the
  server could not be asked, and keep the Dart and Swift shaping in step. New
  widgets must be added to `_iosKinds`/`_androidProviders`, the iOS bundle, the
  manifest and `WidgetConfigActivity`'s provider list. The labels `appsNone`,
  `appsUpdatesOne/Many`, `idle`, `jobScrub`, `jobCloudSync`, `jobCloudBackup`,
  `jobWaiting` are in `homeWidgetLabels`. Untested on a real phone
  as of writing: check the
  widget refreshes with the app closed, over Tailscale, and the pinned
  certificate case.
- History charts (`lib/core/api/reporting_api.dart`, `lib/features/reporting/`):
  `ReportingApi` reads netdata reporting, `reporting.netdata_graphs` +
  `reporting.netdata_get_data` (25.04) or `reporting.graphs` + `reporting.get_data`
  (newer), picked from `core.get_methods`. `get_data` takes
  `[[{name, identifier}], {unit: HOUR|DAY|WEEK|MONTH}]` and answers per graph
  with `legend` (first entry `time`) and `data` rows `[seconds, v1, v2...]`.
  Units come from the graph's `vertical_label` (`bytesPerUnit`): network is
  kilobits per second (sent may be negative), ARC mebibytes; the fallbacks
  match that. `cpu` has no total, so usage is every column but `idle`. Every
  interface and disk is fetched in one request, so the pickers switch without
  asking again; the busiest interface and hottest disk are the default. The
  entry is a row in the dashboard's gauges card, shown when
  `ReportingApi.isAvailable`. Fake server: `reporting`, `failingGraphs`,
  `hiddenGraphs`, `sampleReportingData`. The exact data shape on a real
  server (legend names, `arcsize` columns) is unconfirmed: check it on a NAS.
- App logs (`lib/features/workloads/app_logs_screen.dart`, `WorkloadsApi.appLogs`):
  "Logs" in an app's menu and screen follows a container's output without a
  shell. Containers come from `app.container_console_choices` (as for the
  shell), the lines from the `app.container_log_follow:{app_name,
  container_id, tail_lines}` event source through `core.subscribe`; each event
  has `fields.data` (the line, ANSI codes stripped client side) and optionally
  `timestamp`. `subscribe` accepts events named with or without the argument
  suffix, since which one the middleware uses is unconfirmed on a real NAS. A
  reconnect resubscribes and the server resends the tail, so the screen clears
  first. Docker apps have no events API, so there is no separate events view.
  Fake server: `appLogLines`, `pushLogLine`, `logCollectionWithArgs`.
- Wake-on-LAN (`lib/core/wol/wake_on_lan.dart`): optional per server
  (`ServerInstance.wol`, a `WakeOnLanSettings` with MAC, broadcast address and
  port; null until a MAC is entered, and damaged data only loses the feature,
  never the server). `UdpWakeOnLanSender` sends the magic packet three times
  over a broadcast `RawDatagramSocket`; tests override
  `wakeOnLanSenderProvider` with `FakeWakeOnLanSender`
  (`test/support/wol_fakes.dart`). `wakeServer` (power button in the server
  card and on the connect error screen) sends it and shows a snackbar. The form
  can read the MAC from `interface.query` (`state.hardware_link_address`).
  iOS needs the local network permission (`NSLocalNetworkUsageDescription`,
  already set); never promise delivery, a sleeping NAS may ignore it.
- Disk health (`lib/features/storage/disk_screen.dart`, `StorageApi.smartResults`
  and `runSmartTest`): `smart.test.results` filtered on `["disk","=",name]`
  gives `tests` (newest first, `num` 1 is the newest; `status` SUCCESS, RUNNING,
  ABORTED or a failure) and `current_test.progress`; `smart.test.manual_test`
  takes `[[{identifier, type: SHORT|LONG|CONVEYANCE|OFFLINE}]]` (the disk's
  `identifier`) and reports a refusal per disk in `error`, not as an RPC error.
  Both are gated on `core.get_methods`; the screen polls every 10 s while a test
  runs. The exact payloads are written from the middleware source and unconfirmed
  on a real NAS: check them on one. Fake server: `smart`, `smartTests`,
  `smartProgress`, `smartRejection`.
- System updates and power (`SystemApi`, `lib/features/system/updates_screen.dart`,
  `power_actions.dart`): `UpdateInfo` is normalised across `update.status`
  (code `REBOOT_REQUIRED`, `new_version.filesize/changelog`, both optional) and
  `update.check_available`. The Updates screen can install and restart or
  install and restart later (`applyUpdate(reboot: false)`), and shows "Restart
  now" once an update waits for a restart. Reboot and shutdown both go through
  `confirmPower` (More tab and Updates screen). The job's live progress is the
  existing `JobKind.systemUpdate`.
- Saved servers live in secure storage (`SecureKeyValueStore`). Its Android
  default `resetOnError: true` erases everything when one read fails, so it is
  off; a failed read is retried, then shown as an error with Try again and
  Clear (`InstancesNotifier`), and a list that could not be read is never saved
  over. Changes to the list run through one queue. The encrypted prefs are
  excluded from Android backups (`backup_rules.xml`, `data_extraction_rules.xml`)
  since the Keystore key does not travel.
- Android release APKs must be signed with a fixed key, or Android refuses
  to install one over another ("app not updated"). `release.yml` signs with
  the four `ANDROID_*` secrets; `tools/make-android-keystore.sh` makes them.
  Never generate or commit a signing key without the owner's say-so.
- App updates (`lib/core/updates/`, `lib/features/updates/`) read the public
  GitHub releases API for `ADRIAN3003/truenas-mobile`; nothing else is sent.
  The updater relies on how `release.yml` names things: tags `vX.Y.Z` and
  assets `truenas-mobile-<tag>-<abi>-release.apk` (plus the universal
  `...-release.apk`). Keep those names or change `ReleaseInfo.apkFor` with
  them. It always picks the per-ABI APK: Flutter adds 1000 x ABI to the
  version code of split builds, so a universal APK cannot install over one.
  Installing goes through `MainActivity` (a method channel, a FileProvider on
  the `updates/` cache folder and the `REQUEST_INSTALL_PACKAGES`
  permission); Android's installer verifies the signature, so the fixed
  signing key above is what makes in-app updates possible. Tests fake GitHub
  with `FakeGitHub` and the installer and downloader in
  `test/support/update_fakes.dart`; `updateAutoCheckProvider` is off unless
  `main` turns it on, so widget tests never look for updates by themselves.
- App ID `hu.adrian.truenasmobile` on both platforms. MIT licence.
- Branch names are descriptive kebab-case, e.g. `claude/shell-reverse-proxy`.
- PRs follow `.github/pull_request_template.md`. The owner merges as soon as
  CI is green unless told otherwise.
