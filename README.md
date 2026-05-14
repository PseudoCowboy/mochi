# Mochi Watch App

Mochi is a kawaii watchOS companion app.

## Build Instructions

To build the `Mochi Watch App` target, use the following headless xcodebuild command. This is especially useful for file watchers and Mac-side CI runners:

```bash
xcodebuild \
  -project Mochi.xcodeproj \
  -scheme "Mochi Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  -configuration Debug \
  build
```
Note: Depending on the available simulators, you may need to fall back to `generic/platform=watchOS Simulator` if the specific Apple Watch Series 10 simulator is not installed.
