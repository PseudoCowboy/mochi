# M4-r3 Widget Manual Test Report

Date: 2026-05-23 (UTC)
Host: Linux-compatible static checks; Mac/Xcode and iOS 17+ simulator/device required for visual validation
Branch: `main`

## Static preflight

| Check | Result | Detail |
| --- | --- | --- |
| Source exists: Mochi Summary Widget/MochiSummaryWidget.swift | PASS |  |
| Source exists: Mochi Summary Widget/SummaryWidgetView.swift | PASS |  |
| Source exists: Mochi Summary Widget/SummaryProvider.swift | PASS |  |
| Source exists: Mochi.xcodeproj/project.pbxproj | PASS |  |
| Widget declares only required families | PASS | found=['accessoryCircular', 'systemMedium', 'systemSmall'] |
| Widget gallery copy mentions streak | PASS | description should cover Calm, Over, and streak |
| systemSmall renders streak only | PASS | must not reference calmMinutes/overMinutes in the small branch |
| systemMedium always renders minutes and streak | PASS | streak must render for 0 and 1, not only >= 2 |
| accessoryCircular branch exists | PASS | SummaryWidgetView must handle the declared accessory family |
| accessoryCircular uses lock-screen background | PASS | expected AccessoryWidgetBackground plus tertiary widget container background |
| accessoryCircular uses flame and accent handling | PASS | flame.fill should remain legible in standard and accented rendering modes |
| placeholder returns non-zero streak | PASS | placeholder should use streak: 7 for redacted previews |
| getSnapshot fallback returns non-zero streak | PASS | preview/redacted snapshots should not render an empty circular widget |
| timeline policy remains 15 minutes | PASS | expected Timeline policy .after(now + 15min) |
| App Group read path is unchanged | PASS | provider should read summary.json from group.com.pseudocowboy.mochi |
| iOS app entitlement includes App Group | PASS | found=['group.com.pseudocowboy.mochi'] |
| summary widget entitlement includes App Group | PASS | found=['group.com.pseudocowboy.mochi'] |
| Mochi iOS CODE_SIGN_ENTITLEMENTS | PASS | Mochi iOS/Mochi iOS.entitlements |
| Mochi iOS deployment target >= iOS 17 | PASS | 17.0, 17.0 |
| Mochi Summary Widget CODE_SIGN_ENTITLEMENTS | PASS | Mochi Summary Widget/Mochi Summary Widget.entitlements |
| Mochi Summary Widget deployment target >= iOS 17 | PASS | 17.0, 17.0 |
| SummarySnapshot fixtures cover required values | PASS | streaks=[0, 1, 7, 100] files=4 |
| git diff --check | PASS |  |

## Build preflight

| Scheme | Action | Destination | Result | Detail |
| --- | --- | --- | --- | --- |
| `Mochi iOS` | `build` | `generic/platform=iOS Simulator` | SKIP | static-only run |
| `Mochi iOSTests` | `build-for-testing` | `generic/platform=iOS Simulator` | SKIP | static-only run |

Local note: this was a static-only run, so Mac-side build validation was intentionally skipped.

## SummarySnapshot fixture matrix

| Fixture | Calm | Over | Streak | asOf | Manual use |
| --- | ---: | ---: | ---: | --- | --- |
| `ci/fixtures/m4_r3_widget_summary/streak_0_zero_minutes.json` | 0 | 0 | 0 | `2026-05-23T09:00:00Z` | Copy to App Group `summary.json` or drive the app writer to this value |
| `ci/fixtures/m4_r3_widget_summary/streak_100_high_minutes.json` | 120 | 35 | 100 | `2026-05-23T12:00:00Z` | Copy to App Group `summary.json` or drive the app writer to this value |
| `ci/fixtures/m4_r3_widget_summary/streak_1_calm_only.json` | 12 | 0 | 1 | `2026-05-23T10:00:00Z` | Copy to App Group `summary.json` or drive the app writer to this value |
| `ci/fixtures/m4_r3_widget_summary/streak_7_mixed_minutes.json` | 45 | 10 | 7 | `2026-05-23T11:00:00Z` | Copy to App Group `summary.json` or drive the app writer to this value |

## Manual visual checklist

| Area | Scope | Status |
| --- | --- | --- |
| Xcode preview | systemSmall, systemMedium, accessoryCircular | PENDING: run on Mac/Xcode with iOS 17+ previews |
| Home Screen visual | systemSmall | PENDING: verify streak-only for streak 0, 1, 7, and 100 |
| Home Screen visual | systemMedium | PENDING: verify Calm + Over + streak for streak 0, 1, 7, and 100 |
| Lock Screen visual | accessoryCircular | PENDING: verify 0 renders as 0 and 100 remains legible |
| StandBy visual | accessoryCircular | PENDING: verify standard and accented rendering modes |
| Always-on appearance | accessoryCircular | PENDING: verify isLuminanceReduced keeps streak legible |
| Placeholder/getSnapshot | redacted previews | PENDING: verify non-zero preview streak displays |
| App Group data flow | group.com.pseudocowboy.mochi | PENDING: write via app, then verify widget matches summary.json after refresh |
| Timeline refresh | .after(now + 15min) | PENDING: observe one refresh interval after writing a new snapshot |

## App Group and timeline procedure

1. Build and run `Mochi iOS` on an iOS 17+ simulator or device with the `Mochi Summary Widget` extension embedded.
2. For each fixture, make the app write the equivalent `SummarySnapshot` to App Group `group.com.pseudocowboy.mochi` as `summary.json`; if using simulator filesystem setup, keep JSON date strings ISO-8601 encoded.
3. Add `systemSmall`, `systemMedium`, and `accessoryCircular` widgets, then trigger a timeline reload from the app or wait one 15-minute policy interval.
4. Verify `systemSmall` shows only the streak, `systemMedium` Calm/Over minutes match `summary.json`, and `accessoryCircular` stays legible on Lock Screen and StandBy in standard, accented, and luminance-reduced appearances.

## Bug list

No static preflight bugs are open. File any Mac-side visual/device failures against Apollo or Atlas after the manual run.
