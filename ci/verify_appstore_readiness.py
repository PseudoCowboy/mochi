#!/usr/bin/env python3
"""Verify M5 app-store-readiness project plumbing.

This helper is intentionally dependency-free so it can run both on the
Linux agent VM for static checks and on a Mac runner for the real xcodebuild
verification commands.
"""

from __future__ import annotations

import argparse
import json
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
DERIVED_DATA = Path("build/appstore-readiness-derived-data")

BRAND_COLORS = ("BrandPrimary", "BrandAccent", "CalmGreen", "OverOrange")
REQUIRED_BUILDS = (
    ("Mochi iOS", "generic/platform=iOS"),
    ("Mochi Watch App", "generic/platform=watchOS"),
    ("Mochi Complication", "generic/platform=watchOS"),
)
BONUS_BUILDS = (("Mochi Summary Widget", "generic/platform=iOS"),)


@dataclass
class CheckResult:
    ok: bool
    message: str


class Reporter:
    def __init__(self) -> None:
        self.failures: list[str] = []
        self.warnings: list[str] = []

    def ok(self, message: str) -> None:
        print(f"OK: {message}")

    def warn(self, message: str) -> None:
        self.warnings.append(message)
        print(f"WARN: {message}")

    def fail(self, message: str) -> None:
        self.failures.append(message)
        print(f"FAIL: {message}")


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def scheme_names() -> set[str]:
    return {path.stem for path in SCHEME_DIR.glob("*.xcscheme")}


def extract_sync_roots(project_text: str) -> dict[str, str]:
    roots: dict[str, str] = {}
    section_match = re.search(
        r"/\* Begin PBXFileSystemSynchronizedRootGroup section \*/(.*?)/\* End PBXFileSystemSynchronizedRootGroup section \*/",
        project_text,
        flags=re.S,
    )
    if not section_match:
        return roots

    for match in re.finditer(r"/\* ([^*]+) \*/ = \{(.*?)\n\t\t\};", section_match.group(1), flags=re.S):
        name = match.group(1).strip()
        body = match.group(2)
        path_match = re.search(r"\n\t\t\tpath = (.+?);", body)
        if not path_match:
            continue
        roots[name] = path_match.group(1).strip().strip('"')
    return roots


def extract_exception_sets(project_text: str) -> list[tuple[str, list[str]]]:
    exception_sets: list[tuple[str, list[str]]] = []
    section_match = re.search(
        r"/\* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section \*/(.*?)/\* End PBXFileSystemSynchronizedBuildFileExceptionSet section \*/",
        project_text,
        flags=re.S,
    )
    if not section_match:
        return exception_sets

    for match in re.finditer(r"/\* PBXFileSystemSynchronizedBuildFileExceptionSet \*/ = \{(.*?)\n\t\t\};", section_match.group(1), flags=re.S):
        body = match.group(1)
        target_match = re.search(r"target = [^/]+/\* ([^*]+) \*/;", body)
        target = target_match.group(1).strip() if target_match else "unknown target"
        members_match = re.search(r"membershipExceptions = \((.*?)\);", body, flags=re.S)
        members: list[str] = []
        if members_match:
            members = [member.strip().strip('"') for member in members_match.group(1).split(",") if member.strip()]
        exception_sets.append((target, members))
    return exception_sets


def section_body(project_text: str, section_name: str) -> str:
    section_match = re.search(
        rf"/\* Begin {section_name} section \*/(.*?)/\* End {section_name} section \*/",
        project_text,
        flags=re.S,
    )
    return section_match.group(1) if section_match else ""


def native_target_body(project_text: str, target_name: str) -> str:
    for match in re.finditer(
        r"\n\t\t[0-9A-F]+ /\* ([^*]+) \*/ = \{(.*?)\n\t\t\};",
        section_body(project_text, "PBXNativeTarget"),
        flags=re.S,
    ):
        if match.group(1).strip() == target_name:
            return match.group(2)
    return ""


def resources_phase_body(project_text: str, phase_id: str) -> str:
    phase_match = re.search(
        rf"\n\t\t{re.escape(phase_id)} /\* Resources \*/ = \{{(.*?)\n\t\t\}};",
        section_body(project_text, "PBXResourcesBuildPhase"),
        flags=re.S,
    )
    return phase_match.group(1) if phase_match else ""


def target_resources_body(project_text: str, target_name: str) -> str:
    target = native_target_body(project_text, target_name)
    phase_match = re.search(r"\n\t\t\t\t([0-9A-F]+) /\* Resources \*/,", target)
    return resources_phase_body(project_text, phase_match.group(1)) if phase_match else ""


def target_has_resource(project_text: str, target_name: str, resource_comment: str) -> bool:
    return resource_comment in target_resources_body(project_text, target_name)


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


def target_has_build_setting(project_text: str, target_name: str, key: str, value: str) -> bool:
    config_ids = target_configuration_ids(project_text, target_name)
    return bool(config_ids) and all(
        f"{key} = {value};" in configuration_body(project_text, config_id)
        for config_id in config_ids
    )


def validate_privacy_manifest(path: Path) -> CheckResult:
    if not path.is_file():
        return CheckResult(False, f"missing {path}")
    try:
        payload = plistlib.loads(path.read_bytes())
    except plistlib.InvalidFileException as error:
        return CheckResult(False, f"invalid plist in {path}: {error}")
    if payload.get("NSPrivacyTracking") is not False:
        return CheckResult(False, f"{path} must set NSPrivacyTracking to false")
    accessed = payload.get("NSPrivacyAccessedAPITypes", [])
    categories = {entry.get("NSPrivacyAccessedAPIType") for entry in accessed}
    expected = {
        "NSPrivacyAccessedAPICategoryUserDefaults",
        "NSPrivacyAccessedAPICategoryFileTimestamp",
    }
    if not expected.issubset(categories):
        return CheckResult(False, f"{path} missing required accessed API categories")
    return CheckResult(True, f"{path} declares required privacy API categories")


def contents_file(asset_dir: Path) -> Path:
    return asset_dir / "Contents.json"


def validate_colorset(asset_catalog: Path, name: str) -> CheckResult:
    path = contents_file(asset_catalog / f"{name}.colorset")
    if not path.is_file():
        return CheckResult(False, f"missing {path}")

    try:
        payload = load_json(path)
    except json.JSONDecodeError as error:
        return CheckResult(False, f"invalid JSON in {path}: {error}")

    colors = payload.get("colors", [])
    has_universal = any(color.get("idiom") == "universal" for color in colors)
    has_dark = any(
        appearance.get("appearance") == "luminosity" and appearance.get("value") == "dark"
        for color in colors
        for appearance in color.get("appearances", [])
    )
    if not has_universal or not has_dark:
        return CheckResult(False, f"{path} must include universal and dark luminosity entries")
    return CheckResult(True, f"{path} has universal and dark entries")


def validate_image_set(asset_catalog: Path, name: str) -> CheckResult:
    path = contents_file(asset_catalog / f"{name}.imageset")
    if not path.is_file():
        return CheckResult(False, f"missing {path}")

    try:
        payload = load_json(path)
    except json.JSONDecodeError as error:
        return CheckResult(False, f"invalid JSON in {path}: {error}")

    missing_files = []
    for image in payload.get("images", []):
        filename = image.get("filename")
        if filename and not (path.parent / filename).is_file():
            missing_files.append(str(path.parent / filename))
    if missing_files:
        return CheckResult(False, f"{path} references missing files: {', '.join(missing_files)}")
    if not any(image.get("filename") for image in payload.get("images", [])):
        return CheckResult(False, f"{path} has no image filename entries")
    return CheckResult(True, f"{path} references existing image files")


def validate_app_icon(asset_catalog: Path, platform: str, expected_entries: int) -> CheckResult:
    path = contents_file(asset_catalog / "AppIcon.appiconset")
    if not path.is_file():
        return CheckResult(False, f"missing {path}")

    try:
        payload = load_json(path)
    except json.JSONDecodeError as error:
        return CheckResult(False, f"invalid JSON in {path}: {error}")

    images = payload.get("images", [])
    platform_images = [image for image in images if image.get("platform") == platform]
    if len(platform_images) != expected_entries:
        return CheckResult(False, f"{path} expected {expected_entries} {platform} entries, found {len(platform_images)}")

    missing_files = []
    for image in platform_images:
        filename = image.get("filename")
        if not filename:
            missing_files.append("<missing filename>")
        elif not (path.parent / filename).is_file():
            missing_files.append(str(path.parent / filename))
    if missing_files:
        return CheckResult(False, f"{path} has missing icon files: {', '.join(missing_files)}")
    return CheckResult(True, f"{path} has {expected_entries} {platform} icon file entries")


def record_result(reporter: Reporter, result: CheckResult) -> None:
    if result.ok:
        reporter.ok(result.message)
    else:
        reporter.fail(result.message)


def run_static_checks(reporter: Reporter) -> None:
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
    for scheme, _destination in BONUS_BUILDS:
        if scheme in schemes:
            reporter.ok(f"bonus shared scheme exists: {scheme}")
        else:
            reporter.warn(f"bonus shared scheme is absent: {scheme}")

    roots = extract_sync_roots(project_text)
    for name in ("Mochi", "Mochi iOS", "Mochi Watch App", "Mochi Complication"):
        root = roots.get(name)
        if root:
            reporter.ok(f"PBXFileSystemSynchronizedRootGroup {name} -> {root}")
        else:
            reporter.fail(f"missing PBXFileSystemSynchronizedRootGroup for {name}")

    exception_sets = extract_exception_sets(project_text)
    asset_exceptions = [
        f"{target}: {member}"
        for target, members in exception_sets
        for member in members
        if "Assets.xcassets" in member or member.endswith((".colorset", ".imageset", ".appiconset"))
    ]
    if asset_exceptions:
        reporter.warn(f"asset-related synchronized build exceptions present: {', '.join(asset_exceptions)}")
    elif exception_sets:
        formatted = "; ".join(f"{target}: {', '.join(members)}" for target, members in exception_sets)
        reporter.ok(f"no asset exception-set entries are present ({formatted})")
    else:
        reporter.ok("no PBXFileSystemSynchronizedBuildFileExceptionSet entries are present")

    record_result(reporter, validate_privacy_manifest(Path("Mochi iOS/PrivacyInfo.xcprivacy")))
    if any(target == "Mochi iOS" and "PrivacyInfo.xcprivacy" in members for target, members in exception_sets):
        reporter.ok("Mochi iOS synchronized-root exception excludes PrivacyInfo.xcprivacy from implicit membership")
    else:
        reporter.fail("Mochi iOS synchronized-root exception must list PrivacyInfo.xcprivacy")
    if target_has_resource(project_text, "Mochi iOS", "PrivacyInfo.xcprivacy in Resources"):
        reporter.ok("Mochi iOS resources explicitly include PrivacyInfo.xcprivacy")
    else:
        reporter.fail("Mochi iOS resources must explicitly include PrivacyInfo.xcprivacy")
    if target_has_build_setting(project_text, "Mochi iOS", "ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"):
        reporter.ok("Mochi iOS build configurations use AppIcon")
    else:
        reporter.fail("Mochi iOS build configurations must set ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon")

    mochi_assets = Path("Mochi/Assets.xcassets")
    watch_assets = Path("Mochi Watch App/Assets.xcassets")
    mochi_ios_assets = Path("Mochi iOS/Assets.xcassets")

    for catalog in (mochi_assets, watch_assets):
        if catalog.is_dir():
            reporter.ok(f"asset catalog exists: {catalog}")
        else:
            reporter.fail(f"missing asset catalog: {catalog}")

    for color in BRAND_COLORS:
        record_result(reporter, validate_colorset(mochi_assets, color))
        record_result(reporter, validate_colorset(watch_assets, color))

    record_result(reporter, validate_app_icon(mochi_assets, "ios", 3))
    record_result(reporter, validate_app_icon(watch_assets, "watchos", 1))
    record_result(reporter, validate_image_set(mochi_assets, "LaunchLogo"))

    if "Mochi iOS" in schemes and mochi_ios_assets.is_dir():
        reporter.ok(f"asset catalog exists: {mochi_ios_assets}")
        for color in BRAND_COLORS:
            record_result(reporter, validate_colorset(mochi_ios_assets, color))
        record_result(reporter, validate_app_icon(mochi_ios_assets, "ios", 3))
        record_result(reporter, validate_image_set(mochi_ios_assets, "LaunchLogo"))
    elif "Mochi iOS" in schemes and target_has_resource(project_text, "Mochi iOS", "Assets.xcassets in Resources"):
        reporter.ok("Mochi iOS target explicitly includes shared asset catalog: Mochi/Assets.xcassets")
    elif "Mochi iOS" in schemes:
        reporter.fail(
            "Mochi iOS scheme targets synchronized root 'Mochi iOS', but that root has no Assets.xcassets "
            "and no explicit shared Assets.xcassets resource; BrandPrimary, LaunchLogo, and AppIcon will not be picked up"
        )


def verify_ios_app_privacy_manifest(reporter: Reporter) -> None:
    apps = sorted(DERIVED_DATA.rglob("Mochi iOS.app"))
    if not apps:
        reporter.fail("could not find built Mochi iOS.app under derived data")
        return
    app = apps[-1]
    matches = sorted(app.rglob("PrivacyInfo.xcprivacy"))
    expected = app / "PrivacyInfo.xcprivacy"
    if matches == [expected]:
        reporter.ok(f"PrivacyInfo.xcprivacy is present exactly once at app bundle root: {expected}")
    else:
        formatted = ", ".join(str(match) for match in matches) or "no matches"
        reporter.fail(f"PrivacyInfo.xcprivacy must appear exactly once at {expected}; found {formatted}")


def run_build(scheme: str, destination: str, reporter: Reporter) -> None:
    command = [
        "xcodebuild",
        "-project",
        "Mochi.xcodeproj",
        "-scheme",
        scheme,
        "-destination",
        destination,
        "-derivedDataPath",
        str(DERIVED_DATA),
        "clean",
        "build",
    ]
    print(f"RUN: {' '.join(command)}")
    completed = subprocess.run(command, text=True)
    if completed.returncode == 0:
        reporter.ok(f"xcodebuild succeeded for {scheme} ({destination})")
        if scheme == "Mochi iOS":
            verify_ios_app_privacy_manifest(reporter)
    else:
        reporter.fail(f"xcodebuild failed for {scheme} ({destination}) with exit code {completed.returncode}")


def run_builds(reporter: Reporter, include_bonus: bool) -> None:
    if shutil.which("xcodebuild") is None:
        reporter.warn("xcodebuild is unavailable on this host; run this helper on a Mac to verify build schemes")
        return

    if DERIVED_DATA.exists():
        shutil.rmtree(DERIVED_DATA)
    for scheme, destination in REQUIRED_BUILDS:
        run_build(scheme, destination, reporter)
    if include_bonus:
        for scheme, destination in BONUS_BUILDS:
            if scheme in scheme_names():
                run_build(scheme, destination, reporter)
            else:
                reporter.warn(f"skipping bonus build because shared scheme is absent: {scheme}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify Mochi M5 app-store-readiness plumbing and builds.")
    parser.add_argument("--static-only", action="store_true", help="Run project and asset checks only.")
    parser.add_argument("--include-bonus", action="store_true", help="Attempt the Mochi Summary Widget bonus build when available.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    os.chdir(Path(__file__).resolve().parents[1])
    args = parse_args(argv)
    reporter = Reporter()

    print("== Static project and asset checks ==")
    run_static_checks(reporter)

    if not args.static_only:
        print("== xcodebuild verification ==")
        run_builds(reporter, include_bonus=args.include_bonus)

    if reporter.warnings:
        print("== Warnings ==")
        for warning in reporter.warnings:
            print(f"WARN: {warning}")
    if reporter.failures:
        print("== Failures ==")
        for failure in reporter.failures:
            print(f"FAIL: {failure}")
        return 1
    print("All requested checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
