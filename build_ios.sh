#!/usr/bin/env bash
# Export the iOS Xcode project (Linux can't compile iOS apps) and zip it for the macOS CI build.
# Output: build/ClashCircuit-ios-xcode.zip
# Then: GitHub Actions "iOS build" (.github/workflows/ios.yml) turns it into an unsigned ClashCircuit.ipa
# and attaches it to the release. Needs the Godot 4.3 iOS export template (ios.zip).
set -euo pipefail
cd "$(dirname "$0")"
GD="$HOME/Applications/godot/Godot_v4.3-stable_linux.x86_64"
rm -rf build/ios && mkdir -p build/ios && touch build/.gdignore
"$GD" --headless --path . --import >/dev/null 2>&1 || true
"$GD" --headless --path . --export-release "iOS" build/ios/ClashCircuit.ipa
(cd build/ios && rm -f ../ClashCircuit-ios-xcode.zip && zip -qry ../ClashCircuit-ios-xcode.zip .)
ls -la build/ClashCircuit-ios-xcode.zip
