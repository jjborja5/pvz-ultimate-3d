#!/usr/bin/env bash
# Builds the phone packages from one shared codebase.
#   tools/build_mobile.sh [android|ios|all]
#
# Android needs (see docs/MOBILE_BUILD.md):
#   - Godot 4.5.1 export templates installed
#   - an Android SDK folder with platform-tools/adb and build-tools/<ver>/apksigner,
#     set as export/android/android_sdk_path in Godot's editor settings
#   - a release keystore, passed through environment variables (never committed):
#       GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#       GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
# iOS: exports an Xcode project (build/ios/). Building and signing it needs a Mac with Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."
target="${1:-all}"
GODOT="${GODOT:-godot}"

echo "== import + prebake (character frames and FX textures shipped in the package)"
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless -s res://tools/prebake.gd | grep -c "prebake" | xargs echo "prebaked files:"
"$GODOT" --headless --import >/dev/null 2>&1 || true

if [[ "$target" == "android" || "$target" == "all" ]]; then
  echo "== Android APK"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?set the release keystore path}"
  mkdir -p build/android
  "$GODOT" --headless --export-release "Android" build/android/CastleDominion.apk 2>&1 | grep -E "ERROR|DONE|Signed" || true
  apksigner verify --print-certs build/android/CastleDominion.apk | head -3
  ls -la build/android/CastleDominion.apk
fi

if [[ "$target" == "ios" || "$target" == "all" ]]; then
  echo "== iOS Xcode project"
  rm -rf build/ios && mkdir -p build/ios
  "$GODOT" --headless --export-release "iOS" build/ios/CastleDominion.xcodeproj 2>&1 | grep -E "ERROR|DONE" || true
  (cd build && zip -qr CastleDominion-iOS-Xcode.zip ios)
  ls -la build/CastleDominion-iOS-Xcode.zip
fi
