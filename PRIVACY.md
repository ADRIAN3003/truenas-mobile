# Privacy policy

**TrueNAS Mobile** (package `hu.adrian.truenasmobile`)
Last updated: 8 November 2026

TrueNAS Mobile is a free, open-source app for managing a TrueNAS server from
a phone. This policy says what the app stores, what it sends and where. The
short version: the app talks to the TrueNAS server you point it at, and to
nothing else that belongs to the developer. There is no developer backend, no
account, no analytics, no advertising and no tracking, so the developer never
receives any of your data.

The app is an independent, community project. It is not affiliated with or
endorsed by iXsystems, Inc. TrueNAS is a registered trademark of iXsystems,
Inc.

The source code is public at
<https://github.com/ADRIAN3003/truenas-mobile>, so everything below can be
checked.

## What the app stores on your phone

All of this stays on the phone. None of it is uploaded to the developer.

- **Saved servers**: the name and address you give each server, the user name
  and password or API key you sign in with, the SHA-256 fingerprint of a
  self-signed certificate if you chose to trust one, and optional Wake-on-LAN
  details (MAC address, broadcast address, port). On iOS this is in the
  Keychain. On Android it is in a private file inside the app's own storage
  (protected by Android's app sandbox) and is excluded from Android backups.
- **Settings**: theme, language, haptics, shell font and keys, which
  notifications you want, muted alert types, hidden job types, the default
  server, and similar choices.
- **Notification bookkeeping**: which alert and job ids were already reported,
  so each one is announced once.
- **Error log**: the newest 500 problems (for example a refused request, a
  failed connection or a crash), kept in a file in the app's storage. It
  records the name of the failed call and the answer, never the parameters
  that were sent, and passwords, tokens and keys are removed before anything
  is written. It leaves the phone only if you copy or share it yourself from
  Settings.
- **Home screen widget data**: the last pool, alert, load and activity
  figures read from your server, shown by the widgets. On iOS the sign-in
  details the widgets need are kept in a Keychain group shared only between
  the app and its own widget extension.
- **Downloaded app update** (Android APK from GitHub only): a release APK
  downloaded from GitHub is kept in the app's cache until installed. The
  Google Play version cannot download or install updates itself.

Deleting a server removes its details. "Clear" in the server list and in the
error log removes those. Uninstalling the app removes everything it stored.

## Where the app sends data

- **Your TrueNAS server.** The app connects to the address you enter, using
  the server's own API over HTTPS/WebSocket, to sign in and to show and change
  what you ask for: pools, shares, apps, virtual machines, users, alerts,
  jobs, the web shell and so on. Your credentials go to that server and only
  to it. Whoever runs that server (usually you) controls what it logs. If you
  reach the server through a reverse proxy, VPN or Tailscale, those carry the
  traffic as they would for a browser.
- **Wake-on-LAN** (only if you set it up): a UDP "magic packet" is broadcast on
  your local network to wake your server.
- **GitHub, for app updates and release notes.** In the APK and IPA downloaded
  from this project's GitHub releases, the app asks GitHub's public API for the
  latest release when it opens (you can switch this off in Settings >
  Updates) and when you open Settings > Release notes (`api.github.com`, no
  sign-in). The request carries nothing about you or your servers, but, like
  any web request, GitHub sees your IP address. If you choose to install an
  update on Android, the APK is downloaded from the project's GitHub release.
  GitHub's own
  [privacy statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement)
  applies to that. **The version from Google Play** has no update check and no
  installer and is updated by Google Play. It contacts GitHub only when you
  open Settings > Release notes, to read the notes of this project's releases.
- **App icons.** The Apps screens show icons from the TrueNAS app catalog. The
  catalog gives the app an image address and the app downloads the image from
  that address, which is a host run by the catalog's publisher or the app's
  maintainers, not by the developer. That host sees your IP address, as with
  any image on a web page.
- **Links you open.** Links such as "Source code" or this policy open in your
  phone's browser, which is then governed by that website.

Nothing else is sent anywhere. The app contains no analytics, advertising,
crash-reporting or tracking library, and it does not use your advertising id,
contacts, photos, camera, microphone or location.

## Permissions and phone features

- **Internet / local network**: to reach your server (and GitHub as above, in
  the builds from GitHub).
  iOS asks for local network access to reach a server on your home network.
- **Notifications** (optional): alert and finished-job notifications are made
  on the phone itself. About every 15 minutes, as the phone's scheduler allows,
  the app signs in to your servers directly from the phone, reads the alert and
  job lists and shows a notification. No push service or other server is
  involved. Live job progress (iOS Live Activities, an Android ongoing
  notification) is also drawn from data read from your server.
- **Fingerprint, face or screen lock** (optional app lock): the phone checks
  you. The app only learns whether it succeeded and never receives your
  biometric data.
- **Home screen widgets** (optional): show server status. They read it from
  your server directly or from the data the app saved.
- **Siri and Shortcuts (iOS) and launcher shortcuts (Android)** (optional): let
  you start, stop or restart an app or run a cloud sync from outside the app.
  They use the saved server details on the phone and talk only to your server.
  If you use Siri or Shortcuts, Apple processes your voice requests under
  Apple's own privacy terms, not this policy.
- **Install packages** (Android APK from GitHub only): used only to install an
  app update you chose to download. The Google Play version does not have
  this permission.

## Sharing, selling and retention

The developer does not collect, share or sell your data, because it never
reaches the developer. Data on your phone is kept until you delete it, as
described above. Data on your TrueNAS server is yours and is handled by that
server.

## Children

The app is a server administration tool and is not directed at children.

## Changes

If the app's behaviour changes in a way that affects this policy, this file is
updated in the same release, and the date above changes. Earlier versions are
in the repository history.

## Contact

Questions or concerns about privacy: open an issue at
<https://github.com/ADRIAN3003/truenas-mobile/issues>, or contact the
maintainer through the GitHub profile
<https://github.com/ADRIAN3003>.
