#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not in PATH."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Xcode is required for macOS builds."
  exit 1
fi

flutter config --enable-macos-desktop
flutter pub get
flutter build macos --release

echo "macOS build finished: build/macos/Build/Products/Release/"
