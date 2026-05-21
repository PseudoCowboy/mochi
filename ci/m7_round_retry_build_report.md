# M7 Round C Retry Build Report

Date: 2026-05-21 (UTC)
Host: Linux (`x86_64`, no Xcode toolchain)
Branch: `mythos/m7-tests-r1`

## xcodebuild availability

| Check | Result |
| --- | --- |
| `command -v xcodebuild` | FAIL (exit 1) |
| `xcodebuild -version` | FAIL (exit 127, command not found) |

This VM cannot run the required simulator builds or test-compile passes. The Mac-side Mythos watcher must run the xcodebuild matrix.

## Scheme matrix

| Scheme | Intended action | Local result |
| --- | --- | --- |
| `Mochi Watch App` | watchOS Simulator build | NOT RUN — `xcodebuild` unavailable |
| `Mochi iOS` | iOS Simulator build | NOT RUN — `xcodebuild` unavailable |
| `Mochi Complication` | watchOS Simulator build | NOT RUN — `xcodebuild` unavailable |
| `Mochi Watch AppTests` | watchOS Simulator `build-for-testing` / test compile | NOT RUN — `xcodebuild` unavailable |
| `Mochi iOSTests` | iOS Simulator `build-for-testing` / test compile | NOT RUN — `xcodebuild` unavailable |

## Static checks completed locally

| Check | Result |
| --- | --- |
| Shared scheme XML parse for all `.xcscheme` files | PASS |
| `git diff --check` | PASS |
| `Mochi iOSTests/Support/BGTaskFakes.swift` exists under the iOS test root | PASS |
| `Mochi Watch AppTests/Support/HKHealthStoreFake.swift` exists under the watch test root | PASS |
| Removed stale explicit `TestSupport/Fakes+BGTaskScheduler.swift` / `TestSupport/Fakes+HealthKit.swift` PBX references | PASS |
| New/touched BG/HK observer tests and fakes grep clean for `Date(`, `HKHealthStore(`, `BGTaskScheduler.shared`, timer sleeps, and XCTest waits | PASS |
| Touched `@testable import` names remain `Mochi_iOS` and `Mochi_Watch_App` | PASS |

## Target membership note

The test targets use `PBXFileSystemSynchronizedRootGroup` entries for `Mochi iOSTests` and `Mochi Watch AppTests`, so files placed under each test root are enrolled only in that test target. The support fakes were moved out of the shared `TestSupport` group to avoid accidental cross-target or production membership.
