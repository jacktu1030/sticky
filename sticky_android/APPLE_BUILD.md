# Apple Build Environment

This project can prepare Android builds on Windows, but iOS and macOS app
builds require macOS with Xcode. Apple does not provide the iOS compiler,
simulator runtime, code signing, or App Store packaging tools for Windows.

## Required Mac Environment

- macOS 14 or newer is recommended.
- Xcode from the Mac App Store.
- Xcode Command Line Tools.
- Flutter SDK available in `PATH`.
- CocoaPods for iOS dependencies.
- Apple Developer account if you want to install on a real iPhone, export an
  `.ipa`, or upload to TestFlight/App Store.

## First-Time Setup On Mac

Run these commands on the Mac:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo gem install cocoapods
flutter doctor -v
```

Then copy this `sticky_android` directory to the Mac and run:

```bash
cd sticky_android
chmod +x tools/*.sh
./tools/apple_setup_check.sh
```

## Build iPhone App

Unsigned build, useful for checking whether the iOS project compiles:

```bash
./tools/build_ios.sh nosign
```

Signed release archive, used for real devices/TestFlight/App Store:

```bash
./tools/build_ios.sh signed
```

For signed builds, open `ios/Runner.xcworkspace` in Xcode first and set:

- Bundle Identifier
- Team
- Signing Certificate
- Provisioning Profile

## Build macOS Desktop App

```bash
./tools/build_macos.sh
```

The macOS app output will be under:

```text
build/macos/Build/Products/Release/
```

## Notes

- If `ios/` does not exist, the script runs `flutter create --platforms=ios .`
  to generate it.
- Weather location on iOS will need iOS location permission text in
  `ios/Runner/Info.plist` after the iOS folder is generated.
- A Windows machine cannot produce a valid iOS `.ipa`. Use a Mac or a macOS CI
  runner.
