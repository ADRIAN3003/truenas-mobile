# Publishing on Google Play

The Android app has two flavors of the same code (same application id
`hu.adrian.truenasmobile`, same signing key):

| | `github` | `play` |
|---|---|---|
| Built as | APKs on GitHub Releases | `truenas-mobile-<tag>-play.aab` |
| Updates itself from GitHub | yes | **no** |
| `REQUEST_INSTALL_PACKAGES` and the update `FileProvider` | yes | **no** |
| Update check at start, Settings > Updates | yes | **none** |
| Release notes (read from GitHub only when the user opens them) | yes | yes |

Google Play does not allow an app to install packages or to update itself any
other way than through Play, so the Play bundle has none of it: not just the
Settings rows, but the permission, the provider and the installer code. A check
of the installer's source at runtime would not remove the permission from the
manifest, which is what Play looks at.

How it is built:

- `android/app/build.gradle.kts` defines the two flavors. Anything in
  `android/app/src/github` (manifest entries, `UpdateInstaller.kt`) is only in
  the GitHub build; `android/app/src/play` has an empty `UpdateInstaller`.
- Dart reads the flavor with `appFlavor` (`lib/core/distribution.dart`). In the
  `play` flavor `selfUpdateAllowedProvider` is false: no update switch, no
  "Check for updates", no check at start. Settings > Release notes stays and
  reads the public releases from GitHub, but only when the user opens it.
- `tools/check-play-manifest.sh` reads the merged manifest Gradle built and
  fails if the Play build contains `REQUEST_INSTALL_PACKAGES`,
  `QUERY_ALL_PACKAGES`, exact alarms, location, storage, contacts, camera, an
  advertising id, foreground service permissions and similar. CI runs it on
  every pull request (debug APKs of both flavors, and the release bundle).
- Android builds need a flavor: `flutter run --flavor github`,
  `flutter build apk --flavor github`, `flutter build appbundle --flavor play`.
  (iOS has no flavor.)

## What the Play build declares

Checked against the merged manifest (see `tools/check-play-manifest.sh`, which
prints the list in the CI log).

- **Permissions** (the exact list CI prints for the release bundle): `INTERNET`,
  `USE_BIOMETRIC` and `USE_FINGERPRINT` (optional app lock, the second one added
  by the biometric library),
  `POST_NOTIFICATIONS` and `POST_PROMOTED_NOTIFICATIONS` (alerts, job
  progress), `VIBRATE` (notifications), and what WorkManager adds:
  `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `RECEIVE_BOOT_COMPLETED` (re-schedules the
  15-minute check after a reboot). None of them is restricted or needs a
  declaration form.
- **No** exact alarms, foreground services (the foreground service permissions
  that `workmanager` declares are removed in `AndroidManifest.xml`, because the
  app never starts one), `QUERY_ALL_PACKAGES` (the `<queries>` entries only ask
  for text processing and https links), location, storage, contacts, camera,
  microphone, SMS, or advertising id.
- **Background work**: one periodic WorkManager task (about every 15 minutes, as
  Android allows) that reads alerts and jobs from the user's own NAS and shows a
  local notification. No push service. It is only scheduled when the user turns
  on alert notifications or has a home screen widget.
- **targetSdk** is whatever Flutter 3.47.7 uses (36 at the time of writing).
- **Data safety**: nothing is sent anywhere the user did not point the app at,
  with one thing to know: app icons in the Apps screens are loaded from the
  `icon_url` the user's TrueNAS gives, usually the TrueNAS catalog's own
  host, which sees the phone's IP address like any image on a web page. The
  privacy policy says so. The Play build contacts GitHub only when the user
  opens Settings > Release notes (a user-initiated read of public data,
  disclosed in the privacy policy); it never checks for updates by itself.

## Signing with Play App Signing

Play now requires Play App Signing for new apps. Two keys are involved:

- the **app signing key**, which Google keeps and signs every APK that users
  download with, and
- the **upload key**, which you keep and use to sign the `.aab` you upload.

Use the existing release key (the `ANDROID_*` secrets, see the README) as the
**upload key** and let Google generate the app signing key. If the upload key
is ever lost or leaked, you can ask Play to reset it; the app signing key
cannot be replaced, so it is better that it is not the one on your computer.
Consequence: the app Play installs is signed with a different key than the APKs
on GitHub, so a phone can not switch between the two without uninstalling
(saved servers are lost).

## Making and uploading a bundle

1. Make sure the four `ANDROID_*` signing secrets are set (README, Releases).
2. Bump `version:` in `pubspec.yaml` if you want a new version name (the build
   number is the workflow's run number, which only goes up, as Play needs).
3. Create a release with a tag such as `v0.2.3` (GitHub Releases > Draft a new
   release > choose a new tag on `main`), or run the *Release* workflow from the
   Actions tab with an existing tag. It builds the GitHub APKs, the iOS IPA
   and `truenas-mobile-<tag>-play.aab`, and attaches them to the release.
4. Download `truenas-mobile-<tag>-play.aab` from the release. The job summary of
   the Android job shows its certificate; the SHA-256 must be the one Play
   Console lists for your upload key.
5. In Play Console: **Test and release > Production** (or *Internal testing*
   first) **> Create new release**. On the first release, Play App Signing
   asks you to accept; choose *Use Google-generated key*. Upload the `.aab`,
   write the release notes, review and roll out.

Play rejects a bundle signed with the debug key, which is what the workflow
uses when the secrets are missing (it prints a warning).
