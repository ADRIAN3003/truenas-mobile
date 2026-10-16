#!/usr/bin/env bash
# Makes the key that signs the Android release APKs, and prints the four
# GitHub secrets the release workflow reads.
#
# Android installs an APK over an older one only when both are signed with the
# same key. Without these secrets every release is signed with a new,
# throw-away debug key, and the phone answers "app not installed" or "unable
# to update". Make the key once, keep the file safe (a lost key means every
# user has to uninstall to update), and never commit it (*.jks is git-ignored).
#
# Usage: tools/make-android-keystore.sh [output-file.jks]
set -euo pipefail

keystore="${1:-truenas-mobile-release.jks}"
alias="truenas-mobile"

command -v keytool >/dev/null || { echo "keytool not found: install a JDK" >&2; exit 1; }
command -v openssl >/dev/null || { echo "openssl not found" >&2; exit 1; }
if [ -e "$keystore" ]; then
  echo "$keystore already exists; refusing to overwrite it" >&2
  exit 1
fi

password="$(openssl rand -hex 16)"

keytool -genkeypair -noprompt \
  -keystore "$keystore" -storetype PKCS12 \
  -alias "$alias" -keyalg RSA -keysize 4096 -validity 36500 \
  -storepass "$password" -keypass "$password" \
  -dname "CN=TrueNAS Mobile, O=adrian3003, C=HU"

cat <<MSG

Created $keystore. Back it up somewhere safe, together with the password.

Add these four repository secrets in GitHub (Settings > Secrets and variables
> Actions > New repository secret), then push the next release tag:

ANDROID_KEY_ALIAS       = $alias
ANDROID_KEY_PASSWORD    = $password
ANDROID_STORE_PASSWORD  = $password
ANDROID_KEYSTORE_BASE64 =
$(base64 < "$keystore" | tr -d '\n')

MSG
