# M7 Round C Retry Build Report

Date: 2026-05-22 (UTC)
Host: Linux-compatible static checks; Mac/Xcode required for simulator builds
Branch: `mythos/m7-tests-r1`

## Static checks

| Check | Result | Detail |
| --- | --- | --- |
| Xcode project exists | PASS | Mochi.xcodeproj |
| Shared scheme Mochi Watch App | PASS | Mochi Watch App.xcscheme |
| Shared scheme Mochi iOS | PASS | Mochi iOS.xcscheme |
| Shared scheme Mochi Complication | PASS | Mochi Complication.xcscheme |
| Shared scheme Mochi Watch AppTests | PASS | Mochi Watch AppTests.xcscheme |
| Shared scheme Mochi iOSTests | PASS | Mochi iOSTests.xcscheme |
| Mochi iOSTests synchronized test root | PASS | path = "Mochi iOSTests"; |
| Mochi Watch AppTests synchronized test root | PASS | path = "Mochi Watch AppTests"; |
| No stale shared fake PBX refs | PASS |  |
| Scoped file Mochi iOSTests/SummaryWriterBGTaskIntegrationTests.swift | PASS |  |
| Scoped file Mochi iOSTests/Support/BGTaskFakes.swift | PASS |  |
| Scoped file Mochi Watch AppTests/HeartRateServiceObserverWiringTests.swift | PASS |  |
| Scoped file Mochi Watch AppTests/StressNotifierObserverSmokeTests.swift | PASS |  |
| Scoped file Mochi Watch AppTests/Support/HKHealthStoreFake.swift | PASS |  |
| Scoped tests avoid real framework/time seams | PASS |  |
| git diff --check | PASS |  |

## xcodebuild matrix

| Scheme | Action | Destination | Result | Detail |
| --- | --- | --- | --- | --- |
| `Mochi Watch App` | `build` | `generic/platform=watchOS Simulator` | SKIP | xcodebuild unavailable |
| `Mochi Watch App` | `build-for-testing` | `generic/platform=watchOS Simulator` | SKIP | xcodebuild unavailable |
| `Mochi iOS` | `build` | `generic/platform=iOS Simulator` | SKIP | xcodebuild unavailable |
| `Mochi iOS` | `build-for-testing` | `generic/platform=iOS Simulator` | SKIP | xcodebuild unavailable |
| `Mochi Complication` | `build` | `generic/platform=watchOS Simulator` | SKIP | xcodebuild unavailable |
| `Mochi Complication` | `build-for-testing` | `generic/platform=watchOS Simulator` | SKIP | xcodebuild unavailable |
| `Mochi Watch AppTests` | `build` | `generic/platform=watchOS Simulator` | SKIP | xcodebuild unavailable |
| `Mochi Watch AppTests` | `build-for-testing` | `generic/platform=watchOS Simulator` | SKIP | xcodebuild unavailable |
| `Mochi iOSTests` | `build` | `generic/platform=iOS Simulator` | SKIP | xcodebuild unavailable |
| `Mochi iOSTests` | `build-for-testing` | `generic/platform=iOS Simulator` | SKIP | xcodebuild unavailable |

Local note: `xcodebuild` is unavailable on this host, so simulator builds were not run locally. Run `python3 ci/verify_m7_round_retry_builds.py --require-xcodebuild --write-report ci/m7_round_retry_build_report.md` on the Mac-side watcher to populate PASS/FAIL results.
