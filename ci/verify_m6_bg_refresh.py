#!/usr/bin/env python3
"""Verify M6 iOS background summary refresh plumbing.

This helper is dependency-free and can run static checks on Linux. When run on
macOS with Xcode installed, it also builds the required schemes and verifies the
built Mochi iOS app bundle metadata, linked frameworks, and entitlements.
"""

from __future__ import annotations

import argparse
import os
import plistlib
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


PROJECT = Path("Mochi.xcodeproj/project.pbxproj")
SCHEME_DIR = Path("Mochi.xcodeproj/xcshareddata/xcschemes")
IOS_ENTITLEMENTS = Path("Mochi iOS/Mochi iOS.entitlements")
SUMMARY_WRITER = Path("Mochi iOS/Services/SummaryWriter.swift")
DERIVED_DATA = Path("build/m6-bg-refresh-derived-data")

APP_GROUP = "group.com.pseudocowboy.mochi"
BG_TASK_IDENTIFIER = "com.pseudocowboy.mochi.summary.refresh"
DEFAULTS_KEY = "summaryBackgroundEnabled"

REQUIRED_BUILDS = (
    ("Mochi", "generic/platform=iOS"),
    ("Mochi Watch App", "generic/platform=watchOS"),
    ("Mochi iOS", "generic/platform=iOS"),
)


@dataclass
class Reporter:
    failures: list[str]
    warnings: list[str]

    def ok(self, message: str) -> None:
        print(f"OK: {message}")

    def warn(self, message: str) -> None:
        self.warnings.append(message)
        print(f"WARN: {message}")

    def fail(self, message: str) -> None:
        self.failures.append(message)
        print(f"FAIL: {message}")


def section_body(project_text: str, section_name: str) -> str:
    section_match = re.search(
        rf"/\* Begin {section_name} section \*/(.*?)/\* End {section_name} section \*/",
        project_text,
        flags=re.S,
    )
    return section_match.group(1) if section_match else ""


def native_target_id(project_text: str, target_name: str) -> str | None:
    for match in re.finditer(
        r"\n\t\t([0-9A-F]+) /\* ([^*]+) \*/ = \{(.*?)\n\t\t\};",
        section_body(project_text, "PBXNativeTarget"),
        flags=re.S,
    ):
        if match.group(2).strip() == target_name:
            return match.group(1)
    return None


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
    value = value.replace(",", " ").replace('"', " ")
    return [part for part in value.split() if part]


def all_config_build_setting_values(project_text: str, target_name: str, key: str) -> list[list[str] | None]:
    values: list[list[str] | None] = []
    for config_id in target_configuration_ids(project_text, target_name):
        raw_value = build_setting_raw(configuration_body(project_text, config_id), key)
        values.append(normalize_build_setting(raw_value) if raw_value is not None else None)
    return values


def all_config_values_contain(project_text: str, target_name: str, key: str, expected: set[str]) -> bool:
    values = all_config_build_setting_values(project_text, target_name, key)
    return bool(values) and all(value is not None and expected.issubset(set(value)) for value in values)


def all_config_values_present(project_text: str, target_name: str, key: str) -> bool:
    values = all_config_build_setting_values(project_text, target_name, key)
    return bool(values) and all(value is not None and bool(value) for value in values)


def scheme_names() -> set[str]:
    return {path.stem for path in SCHEME_DIR.glob("*.xcscheme")}


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


def project_target_attributes(project_text: str, target_id: str) -> str:
    target_attributes_index = project_text.find("TargetAttributes = {")
    if target_attributes_index == -1:
        return ""
    opening_brace_index = project_text.find("{", target_attributes_index)
    target_attributes = extract_braced_block(project_text, opening_brace_index)
    target_index = target_attributes.find(f"{target_id} = {{")
    if target_index == -1:
        return ""
    target_opening_brace = target_attributes.find("{", target_index)
    return extract_braced_block(target_attributes, target_opening_brace)


def target_capability_enabled(project_text: str, target_name: str, capability: str) -> bool:
    target_id = native_target_id(project_text, target_name)
    if target_id is None:
        return False
    attributes = project_target_attributes(project_text, target_id)
    capability_index = attributes.find(f"{capability} = {{")
    if capability_index == -1:
        return False
    opening_brace_index = attributes.find("{", capability_index)
    capability_body = extract_braced_block(attributes, opening_brace_index)
    return "enabled = 1;" in capability_body


def load_plist(path: Path) -> dict:
    with path.open("rb") as handle:
        payload = plistlib.load(handle)
    if not isinstance(payload, dict):
        raise ValueError(f"{path} is not a plist dictionary")
    return payload


def plist_values(payload: dict, key: str) -> set[str]:
    value = payload.get(key)
    if isinstance(value, list):
        return {entry for entry in value if isinstance(entry, str)}
    if isinstance(value, str):
        return set(value.split())
    return set()


def verify_source_entitlements(reporter: Reporter) -> None:
    if not IOS_ENTITLEMENTS.is_file():
        reporter.fail(f"missing source entitlements: {IOS_ENTITLEMENTS}")
        return
    try:
        entitlements = load_plist(IOS_ENTITLEMENTS)
    except (OSError, plistlib.InvalidFileException, ValueError) as error:
        reporter.fail(f"invalid source entitlements {IOS_ENTITLEMENTS}: {error}")
        return
    app_groups = plist_values(entitlements, "com.apple.security.application-groups")
    if APP_GROUP in app_groups:
        reporter.ok(f"source iOS entitlements include App Group {APP_GROUP}")
    else:
        reporter.fail(f"source iOS entitlements must include App Group {APP_GROUP}")


def verify_static_project(reporter: Reporter) -> None:
    if not PROJECT.is_file():
        reporter.fail(f"missing {PROJECT}")
        return

    project_text = PROJECT.read_text(encoding="utf-8")
    schemes = scheme_names()
    for scheme, _destination in REQUIRED_BUILDS:
        if scheme in schemes:
            reporter.ok(f"shared scheme exists: {scheme}")
        else:
            reporter.fail(f"missing shared scheme: {scheme}")

    if SUMMARY_WRITER.is_file():
        source = SUMMARY_WRITER.read_text(encoding="utf-8")
        required_fragments = {
            "import BackgroundTasks": "imports BackgroundTasks",
            "import HealthKit": "imports HealthKit",
            BG_TASK_IDENTIFIER: "uses the M6 BG task identifier",
            DEFAULTS_KEY: "uses the M6 UserDefaults key",
            "summary.json": "writes the shared summary.json payload",
        }
        for fragment, description in required_fragments.items():
            if fragment in source:
                reporter.ok(f"SummaryWriter {description}")
            else:
                reporter.fail(f"SummaryWriter must {description}")
    else:
        reporter.fail(f"missing iOS SummaryWriter implementation: {SUMMARY_WRITER}")

    if all_config_values_contain(
        project_text,
        "Mochi iOS",
        "INFOPLIST_KEY_BGTaskSchedulerPermittedIdentifiers",
        {BG_TASK_IDENTIFIER},
    ):
        reporter.ok("Mochi iOS generated Info.plist permits the summary refresh BG task identifier")
    else:
        reporter.fail(f"Mochi iOS Info.plist settings must permit {BG_TASK_IDENTIFIER}")

    if all_config_values_contain(project_text, "Mochi iOS", "INFOPLIST_KEY_UIBackgroundModes", {"fetch", "processing"}):
        reporter.ok("Mochi iOS generated Info.plist declares fetch and processing background modes")
    else:
        reporter.fail("Mochi iOS Info.plist settings must include UIBackgroundModes fetch and processing")

    if all_config_values_present(project_text, "Mochi iOS", "INFOPLIST_KEY_NSHealthShareUsageDescription"):
        reporter.ok("Mochi iOS generated Info.plist declares NSHealthShareUsageDescription")
    else:
        reporter.fail("Mochi iOS Info.plist settings must declare NSHealthShareUsageDescription")

    expected_capabilities = {
        "com.apple.ApplicationGroups": "Application Groups",
        "com.apple.BackgroundModes": "Background Modes",
        "com.apple.HealthKit": "HealthKit",
    }
    for capability, label in expected_capabilities.items():
        if target_capability_enabled(project_text, "Mochi iOS", capability):
            reporter.ok(f"Mochi iOS target enables {label} capability")
        else:
            reporter.fail(f"Mochi iOS target must enable {label} capability")

    verify_source_entitlements(reporter)


def run_command(command: list[str], reporter: Reporter, description: str, capture: bool = False) -> str | None:
    print(f"RUN: {' '.join(command)}")
    completed = subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    if completed.returncode == 0:
        reporter.ok(description)
        return completed.stdout if capture else ""
    output = ""
    if capture:
        output = "\n".join(part for part in (completed.stdout, completed.stderr) if part)
    suffix = f": {output.strip()}" if output.strip() else ""
    reporter.fail(f"{description} failed with exit code {completed.returncode}{suffix}")
    return None


def run_builds(reporter: Reporter, require_xcodebuild: bool, derived_data: Path) -> bool:
    if shutil.which("xcodebuild") is None:
        message = "xcodebuild is unavailable on this host; run this helper on a Mac for full M6 build verification"
        if require_xcodebuild:
            reporter.fail(message)
        else:
            reporter.warn(message)
        return False

    if derived_data.exists():
        shutil.rmtree(derived_data)
    for scheme, destination in REQUIRED_BUILDS:
        command = [
            "xcodebuild",
            "-project",
            "Mochi.xcodeproj",
            "-scheme",
            scheme,
            "-destination",
            destination,
            "-derivedDataPath",
            str(derived_data),
            "build",
        ]
        run_command(command, reporter, f"xcodebuild succeeded for {scheme} ({destination})")
    return True


def latest_ios_app(derived_data: Path) -> Path | None:
    apps = sorted(derived_data.rglob("Mochi iOS.app"), key=lambda path: path.stat().st_mtime)
    return apps[-1] if apps else None


def verify_built_info_plist(app: Path, reporter: Reporter) -> None:
    info_plist = app / "Info.plist"
    if not info_plist.is_file():
        reporter.fail(f"missing built Info.plist: {info_plist}")
        return
    try:
        payload = load_plist(info_plist)
    except (OSError, plistlib.InvalidFileException, ValueError) as error:
        reporter.fail(f"invalid built Info.plist {info_plist}: {error}")
        return

    bg_identifiers = plist_values(payload, "BGTaskSchedulerPermittedIdentifiers")
    if BG_TASK_IDENTIFIER in bg_identifiers:
        reporter.ok(f"built Info.plist permits BG task identifier {BG_TASK_IDENTIFIER}")
    else:
        reporter.fail(f"built Info.plist must permit BG task identifier {BG_TASK_IDENTIFIER}")

    background_modes = plist_values(payload, "UIBackgroundModes")
    if {"fetch", "processing"}.issubset(background_modes):
        reporter.ok("built Info.plist includes UIBackgroundModes fetch and processing")
    else:
        reporter.fail("built Info.plist must include UIBackgroundModes fetch and processing")

    health_usage = payload.get("NSHealthShareUsageDescription")
    if isinstance(health_usage, str) and health_usage.strip():
        reporter.ok("built Info.plist includes NSHealthShareUsageDescription")
    else:
        reporter.fail("built Info.plist must include NSHealthShareUsageDescription")


def verify_linked_healthkit(app: Path, reporter: Reporter) -> None:
    binary = app / "Mochi iOS"
    if not binary.is_file():
        reporter.fail(f"missing built app binary: {binary}")
        return
    if shutil.which("otool") is None:
        reporter.fail("otool is unavailable; cannot verify HealthKit.framework linkage")
        return
    output = run_command(["otool", "-L", str(binary)], reporter, "inspected linked frameworks with otool", capture=True)
    if output is None:
        return
    if "HealthKit.framework/HealthKit" in output:
        reporter.ok("Mochi iOS binary links HealthKit.framework")
    else:
        reporter.fail("Mochi iOS binary must link HealthKit.framework")


def plist_from_command_output(output: str) -> dict | None:
    start = output.find("<?xml")
    if start == -1:
        start = output.find("<plist")
    if start == -1:
        return None
    try:
        payload = plistlib.loads(output[start:].encode("utf-8"))
    except plistlib.InvalidFileException:
        return None
    return payload if isinstance(payload, dict) else None


def verify_signed_entitlements(app: Path, reporter: Reporter) -> None:
    if shutil.which("codesign") is None:
        reporter.fail("codesign is unavailable; cannot verify built app entitlements")
        return
    completed = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(app)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    output = "\n".join(part for part in (completed.stdout, completed.stderr) if part)
    print(f"RUN: codesign -d --entitlements :- {app}")
    if completed.returncode != 0:
        reporter.fail(f"codesign entitlement inspection failed with exit code {completed.returncode}: {output.strip()}")
        return
    payload = plist_from_command_output(output)
    if payload is None:
        reporter.fail("codesign entitlement inspection did not return a plist payload")
        return
    app_groups = plist_values(payload, "com.apple.security.application-groups")
    if APP_GROUP in app_groups:
        reporter.ok(f"built iOS entitlements include App Group {APP_GROUP}")
    else:
        reporter.fail(f"built iOS entitlements must include App Group {APP_GROUP}")


def verify_built_ios_app(reporter: Reporter, derived_data: Path) -> None:
    app = latest_ios_app(derived_data)
    if app is None:
        reporter.fail(f"could not find built Mochi iOS.app under {derived_data}")
        return
    reporter.ok(f"found built Mochi iOS app: {app}")
    verify_built_info_plist(app, reporter)
    verify_linked_healthkit(app, reporter)
    verify_signed_entitlements(app, reporter)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify M6 iOS background summary refresh plumbing and builds.")
    parser.add_argument("--static-only", action="store_true", help="Run static project/source checks only.")
    parser.add_argument(
        "--require-xcodebuild",
        action="store_true",
        help="Fail when xcodebuild is unavailable instead of warning.",
    )
    parser.add_argument(
        "--derived-data-path",
        default=str(DERIVED_DATA),
        help="DerivedData directory for xcodebuild outputs.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    os.chdir(Path(__file__).resolve().parents[1])
    args = parse_args(argv)
    reporter = Reporter(failures=[], warnings=[])
    derived_data = Path(args.derived_data_path)

    print("== Static M6 project checks ==")
    verify_static_project(reporter)

    if not args.static_only:
        print("== M6 xcodebuild verification ==")
        builds_ran = run_builds(reporter, require_xcodebuild=args.require_xcodebuild, derived_data=derived_data)
        if builds_ran:
            print("== Built Mochi iOS.app checks ==")
            verify_built_ios_app(reporter, derived_data)

    if reporter.warnings:
        print("== Warnings ==")
        for warning in reporter.warnings:
            print(f"WARN: {warning}")
    if reporter.failures:
        print("== Failures ==")
        for failure in reporter.failures:
            print(f"FAIL: {failure}")
        return 1
    print("All requested M6 checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
