# M5-r4 App Store Readiness Verification Report

Date: 2026-05-23 (UTC)
Static result: FAIL
Archives requested: no
Manual checklist emitted: yes

## Failures

- iOS AppIcon is missing required default entries: idiom=universal, size=20x20, scale=1x; idiom=universal, size=20x20, scale=2x; idiom=universal, size=20x20, scale=3x; idiom=universal, size=29x29, scale=1x; idiom=universal, size=29x29, scale=2x; idiom=universal, size=29x29, scale=3x; idiom=universal, size=40x40, scale=1x; idiom=universal, size=40x40, scale=2x; idiom=universal, size=40x40, scale=3x; idiom=universal, size=60x60, scale=2x; idiom=universal, size=60x60, scale=3x; idiom=universal, size=76x76, scale=1x; idiom=universal, size=76x76, scale=2x; idiom=universal, size=83.5x83.5, scale=2x; idiom=universal, size=1024x1024, scale=1x
- watchOS AppIcon is missing required entries: idiom=watch, role=notificationCenter, subtype=40mm, size=27.5x27.5, scale=2x; idiom=watch, role=notificationCenter, subtype=41mm, size=29x29, scale=2x; idiom=watch, role=notificationCenter, subtype=44mm, size=29x29, scale=2x; idiom=watch, role=notificationCenter, subtype=45mm, size=29x29, scale=2x; idiom=watch, role=appLauncher, subtype=41mm, size=50x50, scale=2x; idiom=watch, role=appLauncher, subtype=42mm, size=44x44, scale=2x; idiom=watch, role=appLauncher, subtype=45mm, size=50x50, scale=2x; idiom=watch, role=quickLook, subtype=40mm, size=98x98, scale=2x; idiom=watch, role=quickLook, subtype=41mm, size=108x108, scale=2x; idiom=watch, role=quickLook, subtype=45mm, size=108x108, scale=2x
- Mochi iOS build settings must wire INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen
- Mochi iOS target must include LaunchScreen.storyboard in resources
- SummaryView must add rotor/scroll accessibility affordance for paged pages
- Dynamic Type audit still has fixed system sizes: Mochi Watch App/Views/MetricRow.swift:11: .font(.system(size: 8, weight: .bold)); Mochi Watch App/Views/MetricRow.swift:14: .font(.system(size: 14, weight: .bold, design: .rounded)); Mochi Watch App/Views/MetricRow.swift:24: .font(.system(size: 8, weight: .bold)); Mochi Watch App/Views/MetricRow.swift:28: .font(.system(size: 14, weight: .bold, design: .rounded)); Mochi Watch App/Views/MetricRow.swift:31: .font(.system(size: 8, weight: .semibold))

## Warnings

- None

## Manual Checks

- Cold-launch Mochi iOS in Simulator and confirm LaunchScreen.storyboard renders BrandPrimary with centered LaunchLogo, not the generated fallback.
- Temporarily remove UILaunchStoryboardName on a local throwaway change and confirm the generated launch-screen fallback still loads.
- Enable VoiceOver on Watch Simulator and verify PetGlanceView announces each metric tile with distinct label and value.
- With VoiceOver enabled, verify watch gauge segments announce label plus value and provide a hint where tapping changes state or opens the app.
- With VoiceOver enabled, verify SummaryView pages are reachable by page rotor/scroll and each page reads as one combined element.
- Sweep Dynamic Type at xSmall, large, accessibility2, and accessibility3 for SummaryView, PetGlanceView, Settings, and About/settings text; confirm no clipping within each clamp.

## Commands

```bash
ci/verify_appstore_readiness.py --static-only
ci/verify_appstore_readiness.py --require-xcodebuild --include-optional-archives --manual-checklist
```
