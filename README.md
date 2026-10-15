# TrueNAS Mobile

Manage your TrueNAS servers from your phone. TrueNAS Mobile is a Flutter app
for Android and iOS that talks to the official TrueNAS middleware API
(JSON-RPC 2.0 over WebSocket) and supports TrueNAS **25.04 and newer**.

## Features

- **Servers:** save as many TrueNAS servers as you like. Sign in with an API
  key (recommended) or a username, password and 2FA code. Self-signed
  certificates are pinned on first use.
- **Dashboard:** live CPU, memory (with ARC), network and pool health, plus
  system info and an alert summary. Alerts can be dismissed and restored.
- **Jobs:** running and recent jobs with progress, and abort.
- **Storage:** pools with layout, scrub start, pause and stop; datasets and
  zvols (create, delete); snapshots (create, roll back, delete); disks with
  temperatures.
- **Data protection:** periodic snapshot, replication, cloud sync, TrueCloud
  backup and rsync tasks with their last result. Run, stop, enable or
  disable any of them; add, edit and delete snapshot, replication and cloud
  sync tasks.
- **Shares:** SMB and NFS shares (create, edit, delete), services (start,
  stop, start on boot), and read-only views of iSCSI and NVMe-oF.
- **Apps and VMs:** Docker apps (start, stop, redeploy, upgrade, delete),
  virtual machines and containers (start, stop, restart).
- **System:** users and groups, API keys, network and certificates
  (read-only), updates and boot environments, reboot and shut down.
- **Shell:** a terminal on the server, with Esc, Tab, Ctrl+C and arrow keys.
- **API explorer:** every method the server exposes, with its documentation
  and a generated form to call it, so anything without its own screen is
  still reachable.
- **Tablets:** a navigation rail and a two-column dashboard on wide screens.
- **Languages:** English, with everything ready for translations.

## Supported TrueNAS versions

| TrueNAS | API | Status |
|---|---|---|
| 25.04 (Fangtooth) | `v25.04.x` | Supported |
| 25.10 (Goldeye) | `v25.10.x` | Supported |
| 26.0 and later | `v26.0.0`, `v27.0.0`, ... | Supported |

The app reads `GET /api/versions` and connects to the newest API version it
understands, then discovers the available methods with `core.get_methods`, so
features appear or hide based on what your server offers. The legacy REST API
(removed in TrueNAS 26) is never used.

## Install

Download the latest APK or IPA from the
[Releases](https://github.com/ADRIAN3003/truenas-mobile/releases) page.

- **Android:** install `app-release.apk` (or the APK for your CPU, for example
  `app-arm64-v8a-release.apk`). You may need to allow installs from unknown
  sources.
- **iOS:** the IPA is unsigned. Sideload it with a tool such as
  [AltStore](https://altstore.io/) or [Sideloadly](https://sideloadly.io/),
  which sign it with your Apple ID.

## Build from source

Requirements: [Flutter](https://docs.flutter.dev/get-started/install) (stable
channel), Android SDK for Android, Xcode on macOS for iOS.

```sh
git clone https://github.com/ADRIAN3003/truenas-mobile.git
cd truenas-mobile
flutter pub get
flutter run                      # on a connected device or emulator
flutter test                     # unit and widget tests
flutter build apk --release      # Android
flutter build ipa --no-codesign  # iOS (macOS only)
```

## Releases

Pushing a tag like `v0.1.0` runs the release workflow, which builds the APKs,
an AAB and an IPA and attaches them to a GitHub Release.

To sign Android releases, add these repository secrets:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_STORE_PASSWORD` | keystore password |

Without them, release APKs are signed with the debug key.

## Translations

The app is built for multiple languages, with English as the base. All UI
text lives in ARB files under [`lib/l10n/`](lib/l10n/), and `app_en.arb` is
the template. To add a language:

1. Copy `lib/l10n/app_en.arb` to `app_<locale>.arb` (for example
   `app_hu.arb`), set `"@@locale"` and translate the values.
2. Add the locale to `CFBundleLocalizations` in `ios/Runner/Info.plist`.
3. Run `flutter gen-l10n` (it also runs automatically on build).

## Contributing

Issues and pull requests are welcome. Please run `dart format .`,
`flutter analyze` and `flutter test` before opening a PR.

## License

[MIT](LICENSE)

## Disclaimer

This is an independent, community project. It is not affiliated with or
endorsed by iXsystems, Inc. TrueNAS is a registered trademark of iXsystems, Inc.
