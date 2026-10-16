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
- Dialogs, sheets and "more" menus go through `lib/shared/dialogs.dart`
  (`AppDialog` with `showAppDialog`, `showAppSheet`, `AppPopupMenu`), never
  `AlertDialog`, `showDialog`, `showModalBottomSheet` or `PopupMenuButton`
  directly: on iOS they are liquid glass like the system's on iOS 26, which
  Flutter's own Cupertino dialogs are not.
  Dialog buttons come from `dialogAction` (same file), never a bare
  `TextButton`/`FilledButton`. Keep the glass of dialogs, sheets and menus
  plain: no `glassColor`, tint or filled/coloured capsules of our own (they
  looked wrong on a device); only a destructive label is red and a primary
  one bold.
- Haptics go through `lib/shared/haptics.dart`. Use `AppRefreshIndicator`,
  `AppSwitch` and `AppSwitchTile` (in `ui.dart`) instead of the bare Material
  widgets so pull to refresh and switches tick; the Material switch makes no
  haptic of its own, even in its iOS look.
- App ID `hu.adrian.truenasmobile` on both platforms. MIT licence.
- Branch names are descriptive kebab-case, e.g. `claude/shell-reverse-proxy`.
- PRs follow `.github/pull_request_template.md`. The owner merges as soon as
  CI is green unless told otherwise.
