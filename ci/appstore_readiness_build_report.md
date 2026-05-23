# M5-r4 App Store Readiness Verification Report

Date: 2026-05-23 (UTC)
Static result: FAIL
Archives requested: no
Manual checklist emitted: yes

## Failures

- iOS AppIcon is missing required default entries: idiom=ipad, size=20x20, scale=1x; idiom=ipad, size=20x20, scale=2x; idiom=ipad, size=29x29, scale=1x; idiom=ipad, size=29x29, scale=2x; idiom=ipad, size=40x40, scale=1x; idiom=ipad, size=40x40, scale=2x; idiom=ipad, size=76x76, scale=1x
- Mochi iOS build settings must wire INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen
- Mochi iOS target must include LaunchScreen.storyboard in resources
- SummaryView must add rotor/scroll accessibility affordance for paged pages

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
