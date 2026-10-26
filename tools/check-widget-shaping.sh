#!/bin/sh
# Builds the Swift widget shaping (the code the iOS home screen widgets use to
# turn a server's answers into what they draw) and checks it against the same
# fixture as the Dart side, test/core/widgets/widget_shaping_test.dart.
# Needs a Mac (Swift with Foundation and Security).
set -eu
cd "$(dirname "$0")/.."
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -swift-version 5 -o "$out/shape-check" \
  ios/Shared/ServerLink.swift \
  ios/Shared/WidgetKeychain.swift \
  ios/JobActivityWidget/HomeWidgetData.swift \
  ios/JobActivityWidget/WidgetFetch.swift \
  tools/widget-shaping-check/StatusEntry.swift \
  tools/widget-shaping-check/main.swift
"$out/shape-check" test/fixtures/widget_shaping.json
