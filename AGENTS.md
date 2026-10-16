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
  directly. On iOS `AppDialog` is the package's `GlassDialog` (via
  `GlassAlert`, which adds scrolling and lifts it above the keyboard), a choice
  is its `showGlassActionSheet`, a menu its `GlassMenu`. `GlassDialog` takes
  one to three buttons with a plain string label: no icon, no disabled state (a
  button without a handler does nothing), and the title must be a `Text`. So
  `dialogAction` (same file), never a bare `TextButton`/`FilledButton`; a list
  of choices is `showAppChoice`, not a dialog without buttons. Keep the glass
  plain: no `glassColor`, tint or custom colours on it (they looked wrong on a
  device). The one colour on the tab bar is the selected tab's icon and label
  in the accent colour; the package draws a selected tab a second time, 15%
  larger and heavier, which clipped the "D" of Dashboard, so `glass.dart` sets
  `magnification: 1` and equal label weights, and the tab labels stay short.
- Switches, sliders and segmented controls are `AppSwitch`/`AppSwitchTile`,
  `AppSlider` and `AppSegments` (in `ui.dart`): `GlassSwitch`, `GlassSlider`
  and `GlassSegmentedControl` on iOS. Pass `inGlass: true` to `AppSegments` in
  a dialog (glass inside glass distorts). Not ported yet: the scaffolds and
  app bars (still `Scaffold`/`AppBar` with our own `GlassTopEdge` and
  `ChromeInsets`, instead of `GlassScaffold`/`GlassAppBar`), buttons, text
  fields and snackbars (a `GlassToast` needs a live context and would sit over
  the tab bar).
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
- Language is chosen on the phone's own page for the app where there is one:
  iOS Settings, and "App languages" on Android 13+ (`locales_config.xml`,
  `android:localeConfig`, `Info.plist` `CFBundleLocalizations`). There the
  settings row only opens that page (`SystemLanguage`,
  `systemLanguagePageProvider`) and the stored `language` is ignored. Android
  12 and older, and tests, keep the in-app picker. A new language goes in the
  ARB files, `locales_config.xml` and `Info.plist`.
- Apps tab "Update all" upgrades the apps with updates one after another
  (`app.upgrade` is a job per app), after listing them in a confirmation.
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
