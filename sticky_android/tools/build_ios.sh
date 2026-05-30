#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mode="${1:-nosign}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not in PATH."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Xcode is required for iOS builds."
  exit 1
fi

flutter pub get

if [ ! -d "ios" ]; then
  flutter create --platforms=ios .
fi

if [ -f "ios/Podfile" ] && command -v pod >/dev/null 2>&1; then
  (cd ios && pod install)
fi

case "$mode" in
  nosign)
    flutter build ios --release --no-codesign
    ;;
  signed)
    flutter build ipa --release
    ;;
  *)
    echo "Usage: tools/build_ios.sh [nosign|signed]"
    exit 1
    ;;
esac

echo "iOS build finished."
