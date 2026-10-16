<img src="docs/icon/icon-1024.png" width="96" alt="" align="right">

# TrueNAS Mobile

Manage your TrueNAS servers from your phone. TrueNAS Mobile is a Flutter app
for Android and iOS that talks to the official TrueNAS middleware API
(JSON-RPC 2.0 over WebSocket) and supports TrueNAS **25.04 and newer**.

![Server list, dashboard on Android and iOS, storage, apps, and the More and data protection screens in the dark theme](docs/screenshots/overview.png)

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
  disable any of them, and add, edit or delete every kind.
- **Shares:** SMB and NFS shares (create, edit, delete), services (start,
  stop, start on boot), and read-only views of iSCSI and NVMe-oF.
- **Apps and VMs:** Docker apps (start, stop, redeploy, upgrade, delete),
  virtual machines and containers (start, stop, restart), each with a shell.
- **System:** users and groups, API keys, network and certificates
  (read-only), updates and boot environments, reboot and shut down.
- **Shell:** a terminal on the server, with Esc, Tab, Ctrl+C and arrow keys.
- **API explorer:** every method the server exposes, with its documentation
  and a generated form to call it, so anything without its own screen is
  still reachable.
- **Tablets:** a navigation rail and a two-column dashboard on wide screens.
- **Languages:** English and Hungarian, following the device language.

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
| `ANDROID_KEYSTORE_BASE64` | `base64 < upload-keystore.jks \| tr -d '\n'` (works on macOS and Linux) |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_STORE_PASSWORD` | keystore password |

Without them, every release APK is signed with a new throw-away debug key, and
Android refuses to install one release over another ("app not installed" or
"unable to update"). [`tools/make-android-keystore.sh`](tools/make-android-keystore.sh)
makes the key and prints the four values. Keep the key file: with a lost key,
everyone has to uninstall the app before updating. Moving from debug-signed
builds to a signed one also needs one uninstall, which removes the saved
servers from the phone.

## Translations

The app ships in English and Hungarian, with English as the base. All UI
text lives in ARB files under [`lib/l10n/`](lib/l10n/), and `app_en.arb` is
the template. To add a language:

1. Copy `lib/l10n/app_en.arb` to `app_<locale>.arb` (for example
   `app_de.arb`), set `"@@locale"` and translate the values.
2. Add the locale to `CFBundleLocalizations` in `ios/Runner/Info.plist`.
3. Run `flutter gen-l10n` (it also runs automatically on build).

## Screenshots

The screenshots in [`docs/screenshots/`](docs/screenshots/) are rendered from
the test suite's fake server. To regenerate them:

```sh
SCREENSHOTS=1 flutter test test/screenshots --update-goldens
```

The same run also lays them out in `overview.png`, the single image at the
top of this README, so it scales to the screen on phones.

## Contributing

Issues and pull requests are welcome. Please run `dart format .`,
`flutter analyze` and `flutter test` before opening a PR.

## License

[MIT](LICENSE)

## Disclaimer

This is an independent, community project. It is not affiliated with or
endorsed by iXsystems, Inc. TrueNAS is a registered trademark of iXsystems, Inc.
