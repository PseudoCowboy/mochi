# M5 R1 App Store Readiness Build Report

Date: 2026-05-19
Host: Linux agent VM without `xcodebuild`

## Static plumbing check

Command run:

```bash
ci/verify_appstore_readiness.py --static-only
```

Result: failed before Mac-side build verification because the `Mochi iOS` shared scheme builds target `Mochi iOS`, whose `PBXFileSystemSynchronizedRootGroup` is `Mochi iOS/`. The newly added iOS assets currently live under `Mochi/Assets.xcassets`, so `BrandPrimary`, `BrandAccent`, `CalmGreen`, `OverOrange`, `LaunchLogo`, and the iOS `AppIcon` are not picked up by the `Mochi iOS` target.

## Synchronized roots and exception sets

- `Mochi` target uses synchronized root `Mochi/`.
- `Mochi iOS` target uses synchronized root `Mochi iOS/`.
- `Mochi Watch App` target uses synchronized root `Mochi Watch App/`.
- `Mochi Complication` target uses synchronized root `Mochi Complication/`.
- No asset-related `PBXFileSystemSynchronizedBuildFileExceptionSet` entries were required or added.
- The only existing exception-set entries remain `Mochi Complication/Info.plist` and `Mochi Complication/Mochi Complication.entitlements`.

## Build verification

The requested `xcodebuild` commands could not be run on this VM because `xcodebuild` is not installed. Once the iOS assets are moved or mirrored into the `Mochi iOS/` synchronized root, run the helper on a Mac:

```bash
ci/verify_appstore_readiness.py --include-bonus
```

That command runs the required schemes:

```bash
xcodebuild -project Mochi.xcodeproj -scheme "Mochi iOS" -destination "generic/platform=iOS" build
xcodebuild -project Mochi.xcodeproj -scheme "Mochi Watch App" -destination "generic/platform=watchOS" build
xcodebuild -project Mochi.xcodeproj -scheme "Mochi" -destination "generic/platform=watchOS" build
```

Bonus status: `Mochi Summary Widget` files exist, but there is no shared `Mochi Summary Widget.xcscheme` in `Mochi.xcodeproj/xcshareddata/xcschemes`, so the helper reports the bonus scheme as unavailable.
