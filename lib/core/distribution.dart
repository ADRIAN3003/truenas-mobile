import 'package:flutter/services.dart' show appFlavor;

/// The Android flavor of the Google Play bundle (`--flavor play`). The APKs on
/// GitHub Releases are `github`; iOS and tests have no flavor.
const playFlavor = 'play';

/// Whether this build may look for, download and install a newer version of
/// itself from GitHub Releases.
///
/// Google Play does not allow an app to update itself any other way than
/// through Play, so the `play` flavor has no updater at all: no
/// REQUEST_INSTALL_PACKAGES permission and no installer code on the native
/// side (`android/app/src/play`), and here the update rows in Settings and the
/// start-up check are left out. The release notes stay: they only read GitHub
/// when the user opens them.
bool get selfUpdateAllowed => appFlavor != playFlavor;
