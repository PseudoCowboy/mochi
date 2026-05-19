# M6 Background Refresh Verification

- XCTest note: skipped in this Hephaestus pass because `SummaryWriter` keeps the encoder and streak bootstrap helper private and App Group-backed; extracting pure helpers would require app-source edits outside the tests/CI-only scope.
- Static verification: `python3 ci/verify_m6_bg_refresh.py --static-only` passes and confirms the M6 BG task identifier, background modes, HealthKit usage description, HealthKit/Background Modes capabilities, and App Group source entitlements wiring.
- Linux VM note: `xcodebuild`, `otool`, and `codesign` are unavailable here, so full bundle verification must run on the Mac-side watcher.
- Mac command: `python3 ci/verify_m6_bg_refresh.py --require-xcodebuild`
