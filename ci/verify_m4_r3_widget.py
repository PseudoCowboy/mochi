#!/usr/bin/env python3
"""Verify M4-r3 iOS summary widget coverage.

Static checks run on Linux and guard the widget contract that cannot be built
on this VM. Passing ``--require-xcodebuild`` makes Mac-side build validation
mandatory; visual/device checks remain manual and are emitted in the report.
"""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


PROJECT = Path("Mochi.xcodeproj/project.pbxproj")
DERIVED_DATA = Path("build/m4-r3-widget-derived-data")
WIDGET_CONFIG = Path("Mochi Summary Widget/MochiSummaryWidget.swift")
WIDGET_VIEW = Path("Mochi Summary Widget/SummaryWidgetView.swift")
SUMMARY_PROVIDER = Path("Mochi Summary Widget/SummaryProvider.swift")
IOS_ENTITLEMENTS = Path("Mochi iOS/Mochi iOS.entitlements")
WIDGET_ENTITLEMENTS = Path("Mochi Summary Widget/Mochi Summary Widget.entitlements")
FIXTURE_DIR = Path("ci/fixtures/m4_r3_widget_summary")

APP_GROUP = "group.com.pseudocowboy.mochi"
SUMMARY_FILE = "summary.json"
REQUIRED_FAMILIES = {"systemSmall", "systemMedium", "accessoryCircular"}
FORBIDDEN_FAMILIES = {"accessoryRectangular", "accessoryInline"}
REQUIRED_STREAKS = {0, 1, 7, 100}

BUILD_MATRIX = (
    ("Mochi iOS", "generic/platform=iOS Simulator", "build"),
    ("Mochi iOSTests", "generic/platform=iOS Simulator", "build-for-testing"),
)


@dataclass
class Check:
    name: str
    status: str
    detail: str = ""


@dataclass
class BuildResult:
    scheme: str
    action: str
    destination: str
    status: str
    detail: str = ""


@dataclass
class Fixture:
    path: Path
    calm_minutes: int
    over_minutes: int
    streak: int
    as_of: str


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def compact(text: str) -> str:
    return re.sub(r"\s+", "", text)


def section_body(project_text: str, section_name: str) -> str:
    section_match = re.search(
        rf"/\* Begin {section_name} section \*/(.*?)/\* End {section_name} section \*/",
        project_text,
        flags=re.S,
    )
    return section_match.group(1) if section_match else ""


def extract_braced_block(text: str, opening_brace_index: int) -> str:
    depth = 0
    for index in range(opening_brace_index, len(text)):
        character = text[index]
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return text[opening_brace_index + 1 : index]
    return ""


def native_target_body(project_text: str, target_name: str) -> str:
    for match in re.finditer(
        r"\n\t\t[0-9A-F]+ /\* ([^*]+) \*/ = \{(.*?)\n\t\t\};",
        section_body(project_text, "PBXNativeTarget"),
        flags=re.S,
    ):
        if match.group(1).strip() == target_name:
            return match.group(2)
    return ""


def target_configuration_ids(project_text: str, target_name: str) -> list[str]:
    target = native_target_body(project_text, target_name)
    config_list_match = re.search(r"buildConfigurationList = ([0-9A-F]+) /\*", target)
    if not config_list_match:
        return []
    config_list_id = config_list_match.group(1)
    list_match = re.search(
        rf"\n\t\t{re.escape(config_list_id)} /\* .*? \*/ = \{{(.*?)\n\t\t\}};",
        section_body(project_text, "XCConfigurationList"),
        flags=re.S,
    )
    if not list_match:
        return []
    return re.findall(r"\n\t\t\t\t([0-9A-F]+) /\*", list_match.group(1))


def configuration_body(project_text: str, config_id: str) -> str:
    config_match = re.search(
        rf"\n\t\t{re.escape(config_id)} /\* .*? \*/ = \{{(.*?)\n\t\t\}};",
        section_body(project_text, "XCBuildConfiguration"),
        flags=re.S,
    )
    return config_match.group(1) if config_match else ""


def build_setting_raw(configuration: str, key: str) -> str | None:
    match = re.search(rf"\n\s*{re.escape(key)} = (.*?);", configuration, flags=re.S)
    return match.group(1).strip() if match else None


def normalize_build_setting(raw_value: str) -> list[str]:
    value = raw_value.replace("\n", " ").strip()
    if value.startswith("(") and value.endswith(")"):
        value = value[1:-1]
    return [
        quoted or bare
        for quoted, bare in re.findall(r'"([^"]+)"|([^,\s()]+)', value)
        if quoted or bare
    ]


def all_config_build_setting_values(project_text: str, target_name: str, key: str) -> list[list[str] | None]:
    values: list[list[str] | None] = []
    for config_id in target_configuration_ids(project_text, target_name):
        raw_value = build_setting_raw(configuration_body(project_text, config_id), key)
        values.append(normalize_build_setting(raw_value) if raw_value is not None else None)
    return values


def build_setting_contains(project_text: str, target_name: str, key: str, expected: str) -> bool:
    values = all_config_build_setting_values(project_text, target_name, key)
    return bool(values) and all(value is not None and expected in value for value in values)


def build_setting_versions_at_least(
    project_text: str,
    target_name: str,
    key: str,
    minimum: float,
) -> tuple[bool, str]:
    values = all_config_build_setting_values(project_text, target_name, key)
    flattened: list[str] = []
    for value in values:
        if value:
            flattened.extend(value)
    versions: list[float] = []
    for value in flattened:
        match = re.match(r"^(\d+(?:\.\d+)?)$", value)
        if match:
            versions.append(float(match.group(1)))
    return bool(versions) and all(version >= minimum for version in versions), ", ".join(flattened)


def app_groups_in(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    with path.open("rb") as handle:
        payload = plistlib.load(handle)
    value = payload.get("com.apple.security.application-groups") if isinstance(payload, dict) else None
    if isinstance(value, list):
        return {entry for entry in value if isinstance(entry, str)}
    if isinstance(value, str):
        return set(value.split())
    return set()


def supported_families(widget_text: str) -> set[str]:
    match = re.search(r"\.supportedFamilies\s*\(\s*\[(.*?)\]\s*\)", widget_text, flags=re.S)
    if not match:
        return set()
    return set(re.findall(r"\.([A-Za-z][A-Za-z0-9_]*)", match.group(1)))


def function_block(source: str, function_name: str) -> str:
    match = re.search(rf"func\s+{re.escape(function_name)}\b[^{{]*\{{", source)
    if not match:
        return ""
    return extract_braced_block(source, match.end() - 1)


def property_block(source: str, property_name: str) -> str:
    match = re.search(rf"(?:private\s+)?(?:@ViewBuilder\s+)?var\s+{re.escape(property_name)}\s*:[^{{=]+\{{", source)
    if not match:
        return ""
    return extract_braced_block(source, match.end() - 1)


def case_identifier(source: str, family: str) -> str | None:
    match = re.search(
        rf"case\s+\.{re.escape(family)}\s*:\s*(?:return\s+)?([A-Za-z_][A-Za-z0-9_]*)",
        source,
    )
    return match.group(1) if match else None


def block_for_family(source: str, family: str, fallback_names: tuple[str, ...]) -> str:
    names: list[str] = []
    identifier = case_identifier(source, family)
    if identifier:
        names.append(identifier)
    names.extend(name for name in fallback_names if name not in names)
    for name in names:
        block = property_block(source, name)
        if block:
            return block
    return ""


def has_nonzero_streak_literal(block: str) -> bool:
    return bool(re.search(r"streak\s*:\s*[1-9]\d*", block))


def load_fixtures() -> tuple[list[Fixture], list[str]]:
    fixtures: list[Fixture] = []
    errors: list[str] = []
    for path in sorted(FIXTURE_DIR.glob("*.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
            calm_minutes = payload["calmMinutes"]
            over_minutes = payload["overMinutes"]
            streak = payload["streak"]
            as_of = payload["asOf"]
        except (OSError, KeyError, json.JSONDecodeError) as error:
            errors.append(f"{path}: {error}")
            continue

        if not all(isinstance(value, int) and value >= 0 for value in (calm_minutes, over_minutes, streak)):
            errors.append(f"{path}: calmMinutes, overMinutes, and streak must be non-negative integers")
            continue
        if not isinstance(as_of, str):
            errors.append(f"{path}: asOf must be an ISO-8601 string")
            continue
        try:
            datetime.fromisoformat(as_of.replace("Z", "+00:00"))
        except ValueError as error:
            errors.append(f"{path}: invalid asOf {error}")
            continue

        fixtures.append(Fixture(path, calm_minutes, over_minutes, streak, as_of))
    return fixtures, errors


def static_checks() -> tuple[list[Check], list[Fixture]]:
    checks: list[Check] = []
    widget_text = read_text(WIDGET_CONFIG)
    view_text = read_text(WIDGET_VIEW)
    provider_text = read_text(SUMMARY_PROVIDER)
    project_text = read_text(PROJECT)

    for path in (WIDGET_CONFIG, WIDGET_VIEW, SUMMARY_PROVIDER, PROJECT):
        checks.append(Check(f"Source exists: {path}", "PASS" if path.is_file() else "FAIL"))

    families = supported_families(widget_text)
    missing = sorted(REQUIRED_FAMILIES - families)
    forbidden = sorted(FORBIDDEN_FAMILIES & families)
    detail = f"found={sorted(families)}"
    if missing:
        detail += f" missing={missing}"
    if forbidden:
        detail += f" forbidden={forbidden}"
    checks.append(Check("Widget declares only required families", "PASS" if not missing and not forbidden else "FAIL", detail))

    description_mentions_streak = ".description" in widget_text and "streak" in widget_text.lower()
    checks.append(Check(
        "Widget gallery copy mentions streak",
        "PASS" if description_mentions_streak else "FAIL",
        "description should cover Calm, Over, and streak",
    ))

    small_block = block_for_family(view_text, "systemSmall", ("smallView", "smallStreakOnlyView"))
    small_uses_streak = "entry.snapshot.streak" in small_block or "streakBadge" in small_block
    small_uses_minutes = "calmMinutes" in small_block or "overMinutes" in small_block
    checks.append(Check(
        "systemSmall renders streak only",
        "PASS" if small_block and small_uses_streak and not small_uses_minutes else "FAIL",
        "must not reference calmMinutes/overMinutes in the small branch",
    ))

    medium_block = block_for_family(view_text, "systemMedium", ("mediumView", "mediumMinutesAndStreakView"))
    medium_has_minutes = "calmMinutes" in medium_block and "overMinutes" in medium_block
    medium_has_streak = "entry.snapshot.streak" in medium_block or "streakBadge" in medium_block
    medium_gates_streak = "streak >= 2" in compact(medium_block).replace(">=", " >= ") or "streak>=2" in compact(medium_block)
    checks.append(Check(
        "systemMedium always renders minutes and streak",
        "PASS" if medium_block and medium_has_minutes and medium_has_streak and not medium_gates_streak else "FAIL",
        "streak must render for 0 and 1, not only >= 2",
    ))

    view_compact = compact(view_text)
    checks.append(Check(
        "accessoryCircular branch exists",
        "PASS" if "case.accessoryCircular" in view_compact else "FAIL",
        "SummaryWidgetView must handle the declared accessory family",
    ))
    checks.append(Check(
        "accessoryCircular uses lock-screen background",
        "PASS" if "AccessoryWidgetBackground" in view_text and ".containerBackground(.fill.tertiary,for:.widget)" in view_compact else "FAIL",
        "expected AccessoryWidgetBackground plus tertiary widget container background",
    ))
    checks.append(Check(
        "accessoryCircular uses flame and accent handling",
        "PASS" if "flame.fill" in view_text and ("widgetRenderingMode" in view_text or "widgetAccentable" in view_text) else "FAIL",
        "flame.fill should remain legible in standard and accented rendering modes",
    ))

    placeholder_block = function_block(provider_text, "placeholder")
    snapshot_block = function_block(provider_text, "getSnapshot")
    timeline_block = function_block(provider_text, "getTimeline")
    checks.append(Check(
        "placeholder returns non-zero streak",
        "PASS" if has_nonzero_streak_literal(placeholder_block) else "FAIL",
        "placeholder should use streak: 7 for redacted previews",
    ))
    get_snapshot_nonzero = has_nonzero_streak_literal(snapshot_block) or "placeholder(in:" in compact(snapshot_block)
    checks.append(Check(
        "getSnapshot fallback returns non-zero streak",
        "PASS" if get_snapshot_nonzero else "FAIL",
        "preview/redacted snapshots should not render an empty circular widget",
    ))
    checks.append(Check(
        "timeline policy remains 15 minutes",
        "PASS" if ".after" in timeline_block and ("15*60" in compact(timeline_block) or "900" in timeline_block) else "FAIL",
        "expected Timeline policy .after(now + 15min)",
    ))
    checks.append(Check(
        "App Group read path is unchanged",
        "PASS" if APP_GROUP in provider_text and SUMMARY_FILE in provider_text else "FAIL",
        f"provider should read {SUMMARY_FILE} from {APP_GROUP}",
    ))

    for label, path in (("iOS app", IOS_ENTITLEMENTS), ("summary widget", WIDGET_ENTITLEMENTS)):
        try:
            groups = app_groups_in(path)
        except (OSError, plistlib.InvalidFileException) as error:
            checks.append(Check(f"{label} entitlements parse", "FAIL", str(error)))
            continue
        checks.append(Check(
            f"{label} entitlement includes App Group",
            "PASS" if APP_GROUP in groups else "FAIL",
            f"found={sorted(groups)}",
        ))

    entitlement_expectations = (
        ("Mochi iOS", "Mochi iOS/Mochi iOS.entitlements"),
        ("Mochi Summary Widget", "Mochi Summary Widget/Mochi Summary Widget.entitlements"),
    )
    for target_name, entitlement_path in entitlement_expectations:
        checks.append(Check(
            f"{target_name} CODE_SIGN_ENTITLEMENTS",
            "PASS" if build_setting_contains(project_text, target_name, "CODE_SIGN_ENTITLEMENTS", entitlement_path) else "FAIL",
            entitlement_path,
        ))
        deployment_ok, deployment_detail = build_setting_versions_at_least(
            project_text,
            target_name,
            "IPHONEOS_DEPLOYMENT_TARGET",
            17.0,
        )
        checks.append(Check(
            f"{target_name} deployment target >= iOS 17",
            "PASS" if deployment_ok else "FAIL",
            deployment_detail or "missing IPHONEOS_DEPLOYMENT_TARGET",
        ))

    fixtures, fixture_errors = load_fixtures()
    streaks = {fixture.streak for fixture in fixtures}
    has_zero_minutes = any(fixture.calm_minutes == 0 or fixture.over_minutes == 0 for fixture in fixtures)
    has_nonzero_minutes = any(fixture.calm_minutes > 0 and fixture.over_minutes > 0 for fixture in fixtures)
    fixture_detail = f"streaks={sorted(streaks)} files={len(fixtures)}"
    if fixture_errors:
        fixture_detail += f" errors={fixture_errors}"
    checks.append(Check(
        "SummarySnapshot fixtures cover required values",
        "PASS" if not fixture_errors and REQUIRED_STREAKS.issubset(streaks) and has_zero_minutes and has_nonzero_minutes else "FAIL",
        fixture_detail,
    ))

    diff_check = run(["git", "diff", "--check"])
    checks.append(Check("git diff --check", "PASS" if diff_check.returncode == 0 else "FAIL", diff_check.stdout.strip()))
    return checks, fixtures


def build_matrix(require_xcodebuild: bool) -> list[BuildResult]:
    xcodebuild = shutil.which("xcodebuild")
    if not xcodebuild:
        status = "FAIL" if require_xcodebuild else "SKIP"
        return [
            BuildResult(scheme, action, destination, status, "xcodebuild unavailable")
            for scheme, destination, action in BUILD_MATRIX
        ]

    results: list[BuildResult] = []
    for scheme, destination, action in BUILD_MATRIX:
        derived_data = DERIVED_DATA / scheme.replace(" ", "_") / action
        command = [
            xcodebuild,
            "-project",
            "Mochi.xcodeproj",
            "-scheme",
            scheme,
            "-destination",
            destination,
            "-derivedDataPath",
            str(derived_data),
            action,
        ]
        completed = run(command)
        if completed.returncode == 0:
            results.append(BuildResult(scheme, action, destination, "PASS"))
        else:
            tail = "\n".join(completed.stdout.splitlines()[-40:])
            results.append(BuildResult(scheme, action, destination, "FAIL", tail))
    return results


def manual_checks() -> list[tuple[str, str, str]]:
    return [
        ("Xcode preview", "systemSmall, systemMedium, accessoryCircular", "PENDING: run on Mac/Xcode with iOS 17+ previews"),
        ("Home Screen visual", "systemSmall", "PENDING: verify streak-only for streak 0, 1, 7, and 100"),
        ("Home Screen visual", "systemMedium", "PENDING: verify Calm + Over + streak for streak 0, 1, 7, and 100"),
        ("Lock Screen visual", "accessoryCircular", "PENDING: verify 0 renders as 0 and 100 remains legible"),
        ("StandBy visual", "accessoryCircular", "PENDING: verify standard and accented rendering modes"),
        ("Always-on appearance", "accessoryCircular", "PENDING: verify isLuminanceReduced keeps streak legible"),
        ("Placeholder/getSnapshot", "redacted previews", "PENDING: verify non-zero preview streak displays"),
        ("App Group data flow", APP_GROUP, "PENDING: write via app, then verify widget matches summary.json after refresh"),
        ("Timeline refresh", ".after(now + 15min)", "PENDING: observe one refresh interval after writing a new snapshot"),
    ]


def owner_for(check_name: str) -> str:
    apollo_tokens = (
        "Widget",
        "systemSmall",
        "systemMedium",
        "accessoryCircular",
        "placeholder",
        "getSnapshot",
        "timeline",
    )
    atlas_tokens = ("App Group read path", "SummarySnapshot")
    if any(token in check_name for token in apollo_tokens):
        return "Apollo"
    if any(token in check_name for token in atlas_tokens):
        return "Atlas"
    return "Apollo/Atlas coordination"


def current_branch() -> str:
    completed = run(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    return completed.stdout.strip() if completed.returncode == 0 else "unknown"


def escape_table(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", "<br>")


def render_markdown(checks: list[Check], fixtures: list[Fixture], builds: list[BuildResult], require_xcodebuild: bool) -> str:
    today = datetime.now(timezone.utc).date().isoformat()
    branch = current_branch()
    lines = [
        "# M4-r3 Widget Manual Test Report",
        "",
        f"Date: {today} (UTC)",
        "Host: Linux-compatible static checks; Mac/Xcode and iOS 17+ simulator/device required for visual validation",
        f"Branch: `{branch}`",
        "",
        "## Static preflight",
        "",
        "| Check | Result | Detail |",
        "| --- | --- | --- |",
    ]
    for check in checks:
        lines.append(f"| {escape_table(check.name)} | {check.status} | {escape_table(check.detail)} |")

    lines.extend([
        "",
        "## Build preflight",
        "",
        "| Scheme | Action | Destination | Result | Detail |",
        "| --- | --- | --- | --- | --- |",
    ])
    for build in builds:
        lines.append(
            f"| `{escape_table(build.scheme)}` | `{escape_table(build.action)}` | "
            f"`{escape_table(build.destination)}` | {build.status} | {escape_table(build.detail)} |"
        )
    skip_details = {build.detail for build in builds if build.status == "SKIP"}
    if "static-only run" in skip_details:
        lines.extend([
            "",
            "Local note: this was a static-only run, so Mac-side build validation was intentionally skipped.",
        ])
    elif any(build.status == "SKIP" for build in builds):
        lines.extend([
            "",
            "Local note: `xcodebuild` is unavailable on this VM, so Mac-side build validation was not run. Use `python3 ci/verify_m4_r3_widget.py --require-xcodebuild --write-report ci/m4_r3_widget_manual_test_report.md` on the watcher Mac.",
        ])
    elif require_xcodebuild:
        lines.extend(["", "Local note: `xcodebuild` was required for this run."])

    lines.extend([
        "",
        "## SummarySnapshot fixture matrix",
        "",
        "| Fixture | Calm | Over | Streak | asOf | Manual use |",
        "| --- | ---: | ---: | ---: | --- | --- |",
    ])
    for fixture in fixtures:
        lines.append(
            f"| `{fixture.path}` | {fixture.calm_minutes} | {fixture.over_minutes} | "
            f"{fixture.streak} | `{fixture.as_of}` | Copy to App Group `{SUMMARY_FILE}` or drive the app writer to this value |"
        )

    lines.extend([
        "",
        "## Manual visual checklist",
        "",
        "| Area | Scope | Status |",
        "| --- | --- | --- |",
    ])
    for area, scope, status in manual_checks():
        lines.append(f"| {escape_table(area)} | {escape_table(scope)} | {escape_table(status)} |")

    lines.extend([
        "",
        "## App Group and timeline procedure",
        "",
        "1. Build and run `Mochi iOS` on an iOS 17+ simulator or device with the `Mochi Summary Widget` extension embedded.",
        f"2. For each fixture, make the app write the equivalent `SummarySnapshot` to App Group `{APP_GROUP}` as `{SUMMARY_FILE}`; if using simulator filesystem setup, keep JSON date strings ISO-8601 encoded.",
        "3. Add `systemSmall`, `systemMedium`, and `accessoryCircular` widgets, then trigger a timeline reload from the app or wait one 15-minute policy interval.",
        "4. Verify `systemSmall` shows only the streak, `systemMedium` Calm/Over minutes match `summary.json`, and `accessoryCircular` stays legible on Lock Screen and StandBy in standard, accented, and luminance-reduced appearances.",
    ])

    failed_checks = [check for check in checks if check.status == "FAIL" and not check.name.startswith("git diff")]
    lines.extend([
        "",
        "## Bug list",
        "",
    ])
    if not failed_checks:
        lines.append("No static preflight bugs are open. File any Mac-side visual/device failures against Apollo or Atlas after the manual run.")
    else:
        lines.extend([
            "Static preflight found the following handoff bugs to route before final visual sign-off:",
            "",
            "| ID | Owner | Finding | Detail |",
            "| --- | --- | --- | --- |",
        ])
        for index, check in enumerate(failed_checks, start=1):
            lines.append(
                f"| M4-R3-WIDGET-{index:02d} | {owner_for(check.name)} | "
                f"{escape_table(check.name)} | {escape_table(check.detail)} |"
            )

    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-xcodebuild", action="store_true", help="fail when xcodebuild is unavailable")
    parser.add_argument("--static-only", action="store_true", help="skip xcodebuild even if available")
    parser.add_argument("--write-report", type=Path, help="write a Markdown report to this path")
    args = parser.parse_args()

    checks, fixtures = static_checks()
    if args.static_only:
        builds = [
            BuildResult(scheme, action, destination, "SKIP", "static-only run")
            for scheme, destination, action in BUILD_MATRIX
        ]
    else:
        builds = build_matrix(args.require_xcodebuild)

    report = render_markdown(checks, fixtures, builds, args.require_xcodebuild)
    if args.write_report:
        args.write_report.parent.mkdir(parents=True, exist_ok=True)
        args.write_report.write_text(report, encoding="utf-8")
    print(report)

    failed_checks = [check for check in checks if check.status == "FAIL"]
    failed_builds = [build for build in builds if build.status == "FAIL"]
    return 1 if failed_checks or failed_builds else 0


if __name__ == "__main__":
    sys.exit(main())
