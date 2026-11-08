#!/usr/bin/env bash
# Checks the merged AndroidManifest.xml that Gradle built for one flavor.
#
# The Google Play build must not carry the permissions Play restricts, above
# all REQUEST_INSTALL_PACKAGES (the GitHub build's self-updater). A plugin
# update could add one without anyone noticing, so CI looks at the real merged
# manifest, not just at ours.
#
# Usage (after building that flavor):
#   tools/check-play-manifest.sh play [Debug|Release]    # nothing restricted
#   tools/check-play-manifest.sh github [Debug|Release]  # self-update parts are still there
set -euo pipefail

flavor="${1:?usage: $0 play|github [Debug|Release]}"
variant="${2:-}"
case "$flavor" in play | github) ;; *) echo "unknown flavor: $flavor" >&2; exit 2 ;; esac

# Where Gradle puts it depends on the Android Gradle plugin; the folder is
# named after the variant (playDebug, playRelease, githubDebug, ...).
manifest="$(find build -path "*merged_manifests/${flavor}${variant}*" -name AndroidManifest.xml -print 2>/dev/null | head -n 1)"
if [ -z "$manifest" ]; then
  echo "No merged manifest for '${flavor}${variant}' under build/. Build that flavor first." >&2
  exit 1
fi
echo "Merged manifest: $manifest"
echo "Permissions:"
tr '\n' ' ' < "$manifest" | grep -o 'uses-permission[^>]*android:name="[^"]*"' \
  | sed 's/.*android:name="\([^"]*\)"/  \1/' | sort -u

status=0
has() { grep -q "$1" "$manifest"; }

if [ "$flavor" = play ]; then
  # Restricted or special-declaration permissions Play asks about or refuses.
  for forbidden in \
    REQUEST_INSTALL_PACKAGES REQUEST_DELETE_PACKAGES QUERY_ALL_PACKAGES \
    FOREGROUND_SERVICE FOREGROUND_SERVICE_SHORT_SERVICE \
    SCHEDULE_EXACT_ALARM USE_EXACT_ALARM USE_FULL_SCREEN_INTENT \
    MANAGE_EXTERNAL_STORAGE READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE \
    ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION ACCESS_BACKGROUND_LOCATION \
    READ_SMS SEND_SMS READ_CONTACTS READ_CALL_LOG CAMERA RECORD_AUDIO \
    FOREGROUND_SERVICE_DATA_SYNC SYSTEM_ALERT_WINDOW BIND_ACCESSIBILITY_SERVICE \
    com.google.android.gms.permission.AD_ID; do
    if has "android.permission.${forbidden}\"" || has "\"${forbidden}\""; then
      echo "::error::Play manifest contains ${forbidden}" >&2
      status=1
    fi
  done
  # The update installer's FileProvider must be gone as well.
  if has '\.updates"'; then
    echo "::error::Play manifest still has the update FileProvider" >&2
    status=1
  fi
else
  has 'android.permission.REQUEST_INSTALL_PACKAGES"' \
    || { echo "::error::GitHub manifest lost REQUEST_INSTALL_PACKAGES (the updater needs it)" >&2; status=1; }
  has '\.updates"' \
    || { echo "::error::GitHub manifest lost the update FileProvider" >&2; status=1; }
fi

[ "$status" -eq 0 ] && echo "OK: the $flavor manifest is as expected."
exit "$status"
