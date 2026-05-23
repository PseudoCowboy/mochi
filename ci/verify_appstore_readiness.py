#!/usr/bin/env python3
"""Verify M5-r4 App Store readiness plumbing.

The Linux agent can run the static checks in this helper: icon manifests,
launch-screen wiring, and source-level accessibility guardrails. A Mac runner
with Xcode can run the same helper without ``--static-only`` to add archive
validation and, when requested, simulator smoke-test prompts.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


PROJECT_FILE = Path("Mochi.xcodeproj/project.pbxproj")
SCHEME_DIR = Path("Mochi.xcodeproj/xcshareddata/xcschemes")
DERIVED_DATA = Path("build/appstore-readiness-derived-data")

IOS_ASSET_CATALOG = Path("Mochi/Assets.xcassets")
WATCH_ASSET_CATALOG = Path("Mochi Watch App/Assets.xcassets")
IOS_APPICON = IOS_ASSET_CATALOG / "AppIcon.appiconset"
WATCH_APPICON = WATCH_ASSET_CATALOG / "AppIcon.appiconset"
LAUNCH_STORYBOARD = Path("Mochi/LaunchScreen.storyboard")
LAUNCH_LOGO = IOS_ASSET_CATALOG / "LaunchLogo.imageset"

WATCH_ACCESSIBILITY_FILES = (
    Path("Mochi Watch App/Views/PetGlanceView.swift"),
    Path("Mochi Watch App/Views/StressGaugeView.swift"),
    Path("Mochi Watch App/Views/SummaryView.swift"),
    Path("Mochi Watch App/Views/SettingsView.swift"),
    Path("Mochi Watch App/Views/MetricRow.swift"),
    Path("Mochi Complication/StressPetComplicationView.swift"),
)

REQUIRED_ARCHIVES = (
    ("Mochi iOS", "generic/platform=iOS"),
    ("Mochi Watch App", "generic/platform=watchOS"),
)
OPTIONAL_ARCHIVES = (
    ("Mochi", "generic/platform=watchOS"),
    ("Mochi Complication", "generic/platform=watchOS"),
)

BRAND_PRIMARY_HEX = "#FF9F7A"

# iOS universal entries cover iPhone + iPad in this project; iPhone-specific
# notification/settings/spotlight/app entries are still accepted for future
# migration, but the App Store-readiness pass requires this universal matrix.
IOS_REQUIRED_COMBOS = tuple(
    {"idiom": "universal", "size": size, "scale": scale}
    for size, scales in (
        ("20x20", ("1x", "2x", "3x")),
        ("29x29", ("1x", "2x", "3x")),
        ("40x40", ("1x", "2x", "3x")),
        ("60x60", ("2x", "3x")),
        ("76x76", ("1x", "2x")),
        ("83.5x83.5", ("2x",)),
        ("1024x1024", ("1x",)),
    )
    for scale in scales
)
IOS_ALLOWED_IDIOMS = {"iphone", "ipad", "ios-marketing", "universal"}

WATCH_REQUIRED_COMBOS = (
    {"idiom": "watch", "role": "notificationCenter", "subtype": "38mm", "size": "24x24", "scale": "2x"},
    {"idiom": "watch", "role": "notificationCenter", "subtype": "40mm", "size": "27.5x27.5", "scale": "2x"},
    {"idiom": "watch", "role": "notificationCenter", "subtype": "41mm", "size": "29x29", "scale": "2x"},
    {"idiom": "watch", "role": "notificationCenter", "subtype": "42mm", "size": "27.5x27.5", "scale": "2x"},
    {"idiom": "watch", "role": "notificationCenter", "subtype": "44mm", "size": "29x29", "scale": "2x"},
    {"idiom": "watch", "role": "notificationCenter", "subtype": "45mm", "size": "29x29", "scale": "2x"},
    {"idiom": "watch", "role": "companionSettings", "size": "29x29", "scale": "2x"},
    {"idiom": "watch", "role": "companionSettings", "size": "29x29", "scale": "3x"},
    {"idiom": "watch", "role": "appLauncher", "subtype": "38mm", "size": "40x40", "scale": "2x"},
    {"idiom": "watch", "role": "appLauncher", "subtype": "40mm", "size": "44x44", "scale": "2x"},
    {"idiom": "watch", "role": "appLauncher", "subtype": "41mm", "size": "50x50", "scale": "2x"},
    {"idiom": "watch", "role": "appLauncher", "subtype": "42mm", "size": "44x44", "scale": "2x"},
    {"idiom": "watch", "role": "appLauncher", "subtype": "44mm", "size": "50x50", "scale": "2x"},
    {"idiom": "watch", "role": "appLauncher", "subtype": "45mm", "size": "50x50", "scale": "2x"},
    {"idiom": "watch", "role": "quickLook", "subtype": "38mm", "size": "86x86", "scale": "2x"},
    {"idiom": "watch", "role": "quickLook", "subtype": "40mm", "size": "98x98", "scale": "2x"},
    {"idiom": "watch", "role": "quickLook", "subtype": "41mm", "size": "108x108", "scale": "2x"},
    {"idiom": "watch", "role": "quickLook", "subtype": "42mm", "size": "98x98", "scale": "2x"},
    {"idiom": "watch", "role": "quickLook", "subtype": "44mm", "size": "108x108", "scale": "2x"},
    {"idiom": "watch", "role": "quickLook", "subtype": "45mm", "size": "108x108", "scale": "2x"},
    {"idiom": "watch-marketing", "size": "1024x1024", "scale": "1x"},
)


@dataclass
class Reporter:
    failures: list[str]
    warnings: list[str]
    manual: list[str]

    @classmethod
    def create(cls) -> "Reporter":
        return cls(failures=[], warnings=[], manual=[])

    def ok(self, message: str) -> None:
        print(f"OK: {message}")

    def warn(self, message: str) -> None:
        self.warnings.append(message)
        print(f"WARN: {message}")

    def fail(self, message: str) -> None:
        self.failures.append(message)
        print(f"FAIL: {message}")

    def manual_step(self, message: str) -> None:
        self.manual.append(message)
        print(f"MANUAL: {message}")


@dataclass(frozen=True)
class BuildSetting:
    target: str
    key: str
    expected: str


class ManifestError(ValueError):
    pass


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def scheme_names() -> set[str]:
    return {path.stem for path in SCHEME_DIR.glob("*.xcscheme")}


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


def build_setting_value(configuration: str, key: str) -> str | None:
    match = re.search(rf"\n\s*{re.escape(key)} = (.*?);", configuration, flags=re.S)
    if not match:
        return None
    return match.group(1).strip().strip('"')


def target_build_setting_values(project_text: str, target_name: str, key: str) -> list[str | None]:
    return [
        build_setting_value(configuration_body(project_text, config_id), key)
        for config_id in target_configuration_ids(project_text, target_name)
    ]


def target_has_build_setting(project_text: str, target_name: str, key: str, expected: str) -> bool:
    values = target_build_setting_values(project_text, target_name, key)
    return bool(values) and all(value == expected for value in values)


def target_file_system_roots(project_text: str, target_name: str) -> list[str]:
    target = native_target_body(project_text, target_name)
    group_ids_match = re.search(r"fileSystemSynchronizedGroups = \((.*?)\);", target, flags=re.S)
    if not group_ids_match:
        return []
    group_ids = re.findall(r"([0-9A-F]+) /\*", group_ids_match.group(1))
    root_section = section_body(project_text, "PBXFileSystemSynchronizedRootGroup")
    roots: list[str] = []
    for group_id in group_ids:
        group_match = re.search(
            rf"\n\t\t{re.escape(group_id)} /\* .*? \*/ = \{{(.*?)\n\t\t\}};",
            root_section,
            flags=re.S,
        )
        if not group_match:
            continue
        path_match = re.search(r"\n\t\t\tpath = (.+?);", group_match.group(1))
        if path_match:
            roots.append(path_match.group(1).strip().strip('"'))
    return roots


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


def required_key(entry: dict, key: str) -> str:
    value = entry.get(key)
    if not isinstance(value, str) or not value:
        raise ManifestError(f"entry missing {key}: {entry}")
    return value


def entry_signature(entry: dict, keys: Iterable[str]) -> tuple[tuple[str, str], ...]:
    return tuple((key, str(entry.get(key, ""))) for key in keys)


def combo_matches(entry: dict, combo: dict[str, str]) -> bool:
    return all(entry.get(key) == value for key, value in combo.items())


def combo_label(combo: dict[str, str]) -> str:
    return ", ".join(f"{key}={value}" for key, value in combo.items())


def image_pixel_size(icon_dir: Path, filename: str) -> tuple[int, int] | None:
    try:
        import struct

        with (icon_dir / filename).open("rb") as handle:
            header = handle.read(24)
        if len(header) < 24 or not header.startswith(b"\x89PNG\r\n\x1a\n"):
            return None
        return struct.unpack(">II", header[16:24])
    except OSError:
        return None


def expected_pixels(entry: dict) -> int | None:
    size = entry.get("size")
    scale = entry.get("scale", "1x")
    if not isinstance(size, str) or "x" not in size or not isinstance(scale, str) or not scale.endswith("x"):
        return None
    width, height = size.split("x", 1)
    if width != height:
        return None
    try:
        return round(float(width) * float(scale[:-1]))
    except ValueError:
        return None


def validate_filename_resolution(icon_dir: Path, images: list[dict], reporter: Reporter, label: str) -> None:
    manifest_files: set[str] = set()
    missing_files: list[str] = []
    wrong_pixels: list[str] = []

    for entry in images:
        try:
            filename = required_key(entry, "filename")
        except ManifestError as error:
            missing_files.append(str(error))
            continue
        manifest_files.add(filename)
        file_path = icon_dir / filename
        if not file_path.is_file():
            missing_files.append(str(file_path))
            continue
        pixels = expected_pixels(entry)
        actual = image_pixel_size(icon_dir, filename)
        if pixels and actual and actual != (pixels, pixels):
            wrong_pixels.append(f"{filename}: expected {pixels}x{pixels}, found {actual[0]}x{actual[1]}")

    disk_pngs = {path.name for path in icon_dir.glob("*.png")}
    orphan_pngs = sorted(disk_pngs - manifest_files)

    if missing_files:
        reporter.fail(f"{label} icon manifest references missing filenames: {', '.join(missing_files)}")
    else:
        reporter.ok(f"{label} icon manifest filenames all exist")

    if wrong_pixels:
        reporter.fail(f"{label} icon PNG dimensions mismatch manifest: {'; '.join(wrong_pixels)}")
    else:
        reporter.ok(f"{label} icon PNG dimensions match declared sizes")

    if orphan_pngs:
        reporter.fail(f"{label} icon set has orphan PNGs not declared in Contents.json: {', '.join(orphan_pngs)}")
    else:
        reporter.ok(f"{label} icon set has no orphan PNGs")


def validate_ios_app_icon(reporter: Reporter) -> None:
    contents_path = IOS_APPICON / "Contents.json"
    if not contents_path.is_file():
        reporter.fail(f"missing iOS AppIcon manifest: {contents_path}")
        return

    try:
        payload = load_json(contents_path)
    except json.JSONDecodeError as error:
        reporter.fail(f"invalid JSON in {contents_path}: {error}")
        return

    images = payload.get("images", [])
    if not isinstance(images, list):
        reporter.fail(f"{contents_path} images must be an array")
        return

    default_images = [image for image in images if "appearances" not in image]
    validate_filename_resolution(IOS_APPICON, images, reporter, "iOS")

    missing = [combo_label(combo) for combo in IOS_REQUIRED_COMBOS if not any(combo_matches(image, combo) for image in default_images)]
    if missing:
        reporter.fail(f"iOS AppIcon is missing required default entries: {'; '.join(missing)}")
    else:
        reporter.ok(f"iOS AppIcon includes all {len(IOS_REQUIRED_COMBOS)} required default entries")

    unexpected_idioms = sorted({image.get("idiom", "<missing>") for image in images} - IOS_ALLOWED_IDIOMS)
    if unexpected_idioms:
        reporter.fail(f"iOS AppIcon has unexpected idioms: {', '.join(unexpected_idioms)}")
    else:
        reporter.ok("iOS AppIcon idioms are valid")

    dark = [image for image in images if any(a.get("appearance") == "luminosity" and a.get("value") == "dark" for a in image.get("appearances", []))]
    tinted = [image for image in images if any(a.get("appearance") == "luminosity" and a.get("value") == "tinted" for a in image.get("appearances", []))]
    if any(image.get("size") == "1024x1024" and image.get("filename") == "icon-dark-1024.png" for image in dark):
        reporter.ok("iOS dark 1024 marketing icon is preserved")
    else:
        reporter.fail("iOS AppIcon must preserve icon-dark-1024.png as the dark 1024 appearance")
    if any(image.get("size") == "1024x1024" and image.get("filename") == "icon-tinted-1024.png" for image in tinted):
        reporter.ok("iOS tinted 1024 marketing icon is preserved")
    else:
        reporter.fail("iOS AppIcon must preserve icon-tinted-1024.png as the tinted 1024 appearance")

    duplicate_keys = find_duplicate_icon_entries(default_images, ("idiom", "size", "scale"))
    if duplicate_keys:
        reporter.fail(f"iOS AppIcon has duplicate idiom/size/scale entries: {'; '.join(duplicate_keys)}")
    else:
        reporter.ok("iOS AppIcon has no duplicate default idiom/size/scale entries")


def validate_watch_app_icon(reporter: Reporter) -> None:
    contents_path = WATCH_APPICON / "Contents.json"
    if not contents_path.is_file():
        reporter.fail(f"missing watchOS AppIcon manifest: {contents_path}")
        return

    try:
        payload = load_json(contents_path)
    except json.JSONDecodeError as error:
        reporter.fail(f"invalid JSON in {contents_path}: {error}")
        return

    images = payload.get("images", [])
    if not isinstance(images, list):
        reporter.fail(f"{contents_path} images must be an array")
        return

    validate_filename_resolution(WATCH_APPICON, images, reporter, "watchOS")

    missing = [combo_label(combo) for combo in WATCH_REQUIRED_COMBOS if not any(combo_matches(image, combo) for image in images)]
    if missing:
        reporter.fail(f"watchOS AppIcon is missing required entries: {'; '.join(missing)}")
    else:
        reporter.ok(f"watchOS AppIcon includes all {len(WATCH_REQUIRED_COMBOS)} required entries")

    missing_role_keys: list[str] = []
    for image in images:
        idiom = image.get("idiom")
        if idiom == "watch":
            for key in ("role", "size", "scale", "filename"):
                if not image.get(key):
                    missing_role_keys.append(f"{image}: missing {key}")
        elif idiom == "watch-marketing":
            for key in ("size", "scale", "filename"):
                if not image.get(key):
                    missing_role_keys.append(f"{image}: missing {key}")
        else:
            missing_role_keys.append(f"{image}: idiom must be watch or watch-marketing")
    if missing_role_keys:
        reporter.fail(f"watchOS AppIcon entries have invalid keys: {'; '.join(missing_role_keys)}")
    else:
        reporter.ok("watchOS AppIcon entries include required role/subtype metadata")

    duplicate_keys = find_duplicate_icon_entries(images, ("idiom", "role", "subtype", "size", "scale"))
    if duplicate_keys:
        reporter.fail(f"watchOS AppIcon has duplicate role/subtype/size/scale entries: {'; '.join(duplicate_keys)}")
    else:
        reporter.ok("watchOS AppIcon has no duplicate role/subtype/size/scale entries")


def find_duplicate_icon_entries(images: list[dict], keys: tuple[str, ...]) -> list[str]:
    seen: set[tuple[tuple[str, str], ...]] = set()
    duplicates: list[str] = []
    for image in images:
        key = entry_signature(image, keys)
        if key in seen:
            duplicates.append(", ".join(f"{name}={value or '<missing>'}" for name, value in key))
        seen.add(key)
    return duplicates


def validate_launch_logo(reporter: Reporter) -> None:
    contents_path = LAUNCH_LOGO / "Contents.json"
    if not contents_path.is_file():
        reporter.fail(f"missing LaunchLogo image set manifest: {contents_path}")
        return
    try:
        payload = load_json(contents_path)
    except json.JSONDecodeError as error:
        reporter.fail(f"invalid JSON in {contents_path}: {error}")
        return

    missing_files = []
    for image in payload.get("images", []):
        filename = image.get("filename")
        if filename and not (LAUNCH_LOGO / filename).is_file():
            missing_files.append(str(LAUNCH_LOGO / filename))
    if missing_files:
        reporter.fail(f"LaunchLogo references missing files: {', '.join(missing_files)}")
    elif any(image.get("filename") for image in payload.get("images", [])):
        reporter.ok("LaunchLogo image set resolves to existing files")
    else:
        reporter.fail("LaunchLogo image set must declare at least one image file")


def validate_launch_storyboard(project_text: str, reporter: Reporter) -> None:
    if not LAUNCH_STORYBOARD.is_file():
        reporter.fail(f"missing SwiftUI-backed launch storyboard: {LAUNCH_STORYBOARD}")
        return

    storyboard = read_text(LAUNCH_STORYBOARD)
    if 'name="BrandPrimary"' in storyboard or "BrandPrimary" in storyboard:
        reporter.ok("LaunchScreen.storyboard references BrandPrimary")
    else:
        reporter.fail("LaunchScreen.storyboard must use named BrandPrimary background")

    if 'image="LaunchLogo"' in storyboard or "LaunchLogo" in storyboard:
        reporter.ok("LaunchScreen.storyboard centers LaunchLogo")
    else:
        reporter.fail("LaunchScreen.storyboard must reference LaunchLogo")

    if target_has_build_setting(project_text, "Mochi iOS", "INFOPLIST_KEY_UILaunchStoryboardName", "LaunchScreen"):
        reporter.ok("Mochi iOS build settings wire UILaunchStoryboardName = LaunchScreen")
    else:
        reporter.fail("Mochi iOS build settings must wire INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen")

    if target_has_build_setting(project_text, "Mochi iOS", "INFOPLIST_KEY_UILaunchScreen_Generation", "YES"):
        reporter.ok("Mochi iOS retains UILaunchScreen generation fallback")
    else:
        reporter.fail("Mochi iOS must retain INFOPLIST_KEY_UILaunchScreen_Generation = YES")

    if target_has_resource(project_text, "Mochi iOS", "LaunchScreen.storyboard in Resources"):
        reporter.ok("Mochi iOS resources include LaunchScreen.storyboard")
    else:
        roots = target_file_system_roots(project_text, "Mochi iOS")
        if any((Path(root) / LAUNCH_STORYBOARD.name).is_file() for root in roots):
            reporter.ok("LaunchScreen.storyboard is inside Mochi iOS synchronized root")
        else:
            reporter.fail("Mochi iOS target must include LaunchScreen.storyboard in resources")


def validate_asset_reachability(project_text: str, reporter: Reporter) -> None:
    for target, catalog in (("Mochi", IOS_ASSET_CATALOG), ("Mochi Watch App", WATCH_ASSET_CATALOG)):
        if catalog.is_dir():
            reporter.ok(f"asset catalog exists for {target}: {catalog}")
        else:
            reporter.fail(f"missing asset catalog for {target}: {catalog}")

    if target_has_build_setting(project_text, "Mochi iOS", "ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"):
        reporter.ok("Mochi iOS build settings use AppIcon")
    else:
        reporter.fail("Mochi iOS build settings must set ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon")

    roots = target_file_system_roots(project_text, "Mochi iOS")
    if "Mochi" in roots or target_has_resource(project_text, "Mochi iOS", "Assets.xcassets in Resources"):
        reporter.ok("Mochi iOS target can see shared Mochi/Assets.xcassets")
    elif Path("Mochi iOS/Assets.xcassets").is_dir():
        reporter.ok("Mochi iOS target has its own Assets.xcassets")
    else:
        reporter.fail(
            "Mochi iOS target must include the AppIcon/BrandPrimary/LaunchLogo asset catalog "
            "from Mochi/Assets.xcassets or mirror it under Mochi iOS/Assets.xcassets"
        )


def validate_accessibility_source(reporter: Reporter) -> None:
    for path in WATCH_ACCESSIBILITY_FILES:
        if path.is_file():
            reporter.ok(f"accessibility source present: {path}")
        else:
            reporter.fail(f"missing accessibility source: {path}")

    pet_glance = read_text(Path("Mochi Watch App/Views/PetGlanceView.swift"))
    for phrase in ("Current Reading", "Stress State", "accessibilityValue"):
        if phrase in pet_glance:
            reporter.ok(f"PetGlanceView includes {phrase} accessibility coverage")
        else:
            reporter.fail(f"PetGlanceView missing {phrase} accessibility coverage")
    if "Stress Gauge" in pet_glance or "StressGaugeView" in pet_glance:
        reporter.ok("PetGlanceView includes gauge accessibility surface")
    else:
        reporter.fail("PetGlanceView must expose gauge accessibility")

    stress_gauge = read_text(Path("Mochi Watch App/Views/StressGaugeView.swift"))
    for phrase in ("accessibilityLabel", "accessibilityValue", "accessibilityHint"):
        if phrase in stress_gauge:
            reporter.ok(f"StressGaugeView includes {phrase}")
        else:
            reporter.fail(f"StressGaugeView missing {phrase}")

    summary = read_text(Path("Mochi Watch App/Views/SummaryView.swift"))
    for phrase in ("accessibilityElement(children: .combine)", "accessibilityLabel", "accessibilityValue"):
        if phrase in summary:
            reporter.ok(f"SummaryView includes {phrase}")
        else:
            reporter.fail(f"SummaryView missing {phrase}")
    if "accessibilityRotor" in summary or ".accessibilityScrollAction" in summary:
        reporter.ok("SummaryView includes explicit page rotor/scroll accessibility affordance")
    else:
        reporter.fail("SummaryView must add rotor/scroll accessibility affordance for paged pages")

    complication = read_text(Path("Mochi Complication/StressPetComplicationView.swift"))
    for phrase in ("accessibilityLabel", "accessibilityValue", "accessibilityHint"):
        if phrase in complication:
            reporter.ok(f"StressPetComplicationView includes {phrase}")
        else:
            reporter.fail(f"StressPetComplicationView missing {phrase}")

    fixed_font_hits: list[str] = []
    for path in WATCH_ACCESSIBILITY_FILES:
        text = read_text(path)
        for line_number, line in enumerate(text.splitlines(), start=1):
            if ".font(.system(size:" in line:
                fixed_font_hits.append(f"{path}:{line_number}: {line.strip()}")
    if fixed_font_hits:
        reporter.fail("Dynamic Type audit still has fixed system sizes: " + "; ".join(fixed_font_hits))
    else:
        reporter.ok("Dynamic Type audit found no fixed .font(.system(size:)) usage in scoped views")

    clamp_missing = [
        str(path)
        for path in (Path("Mochi Watch App/Views/PetGlanceView.swift"), Path("Mochi Watch App/Views/SummaryView.swift"))
        if "dynamicTypeSize" not in read_text(path)
    ]
    if clamp_missing:
        reporter.fail(f"Dynamic Type clamp missing from text-heavy views: {', '.join(clamp_missing)}")
    else:
        reporter.ok("Text-heavy watch views declare Dynamic Type clamps")


def validate_static_project(reporter: Reporter) -> None:
    if not PROJECT_FILE.is_file():
        reporter.fail(f"missing project file: {PROJECT_FILE}")
        return

    project_text = PROJECT_FILE.read_text(encoding="utf-8")
    schemes = scheme_names()
    for scheme, _destination in REQUIRED_ARCHIVES:
        if scheme in schemes:
            reporter.ok(f"shared scheme exists: {scheme}")
        else:
            reporter.fail(f"missing shared scheme: {scheme}")
    for scheme, _destination in OPTIONAL_ARCHIVES:
        if scheme in schemes:
            reporter.ok(f"optional shared scheme exists: {scheme}")
        else:
            reporter.warn(f"optional shared scheme is absent: {scheme}")

    validate_asset_reachability(project_text, reporter)
    validate_ios_app_icon(reporter)
    validate_watch_app_icon(reporter)
    validate_launch_logo(reporter)
    validate_launch_storyboard(project_text, reporter)
    validate_accessibility_source(reporter)


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def archive_scheme(scheme: str, destination: str, reporter: Reporter) -> None:
    archive_path = DERIVED_DATA / "archives" / f"{scheme.replace(' ', '_')}.xcarchive"
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
        "-archivePath",
        str(archive_path),
        "archive",
    ]
    print(f"RUN: {' '.join(command)}")
    completed = run(command)
    if completed.returncode == 0:
        reporter.ok(f"xcodebuild archive succeeded for {scheme}")
    else:
        tail = "\n".join(completed.stdout.splitlines()[-80:])
        reporter.fail(f"xcodebuild archive failed for {scheme} with exit code {completed.returncode}\n{tail}")
        return

    validation_hits = [
        line
        for line in completed.stdout.splitlines()
        if re.search(r"missing required icon|invalid Contents\.json|AppIcon|app icon", line, flags=re.I)
    ]
    warnings_or_errors = [line for line in validation_hits if re.search(r"warning:|error:|missing|required|invalid", line, flags=re.I)]
    if warnings_or_errors:
        reporter.fail(f"asset validation warnings/errors for {scheme}: {' | '.join(warnings_or_errors[-20:])}")
    else:
        reporter.ok(f"no AppIcon/Contents.json validation warnings found for {scheme}")


def run_archives(reporter: Reporter, include_optional: bool, require_xcodebuild: bool) -> None:
    if shutil.which("xcodebuild") is None:
        message = "xcodebuild unavailable on this host; run this helper on the Mac-side watcher for archive validation"
        if require_xcodebuild:
            reporter.fail(message)
        else:
            reporter.warn(message)
        return

    if DERIVED_DATA.exists():
        shutil.rmtree(DERIVED_DATA)
    for scheme, destination in REQUIRED_ARCHIVES:
        archive_scheme(scheme, destination, reporter)
    if include_optional:
        for scheme, destination in OPTIONAL_ARCHIVES:
            if scheme in scheme_names():
                archive_scheme(scheme, destination, reporter)
            else:
                reporter.warn(f"skipping optional archive because shared scheme is absent: {scheme}")


def print_manual_checklist(reporter: Reporter) -> None:
    checklist = (
        "Cold-launch Mochi iOS in Simulator and confirm LaunchScreen.storyboard renders BrandPrimary with centered LaunchLogo, not the generated fallback.",
        "Temporarily remove UILaunchStoryboardName on a local throwaway change and confirm the generated launch-screen fallback still loads.",
        "Enable VoiceOver on Watch Simulator and verify PetGlanceView announces each metric tile with distinct label and value.",
        "With VoiceOver enabled, verify watch gauge segments announce label plus value and provide a hint where tapping changes state or opens the app.",
        "With VoiceOver enabled, verify SummaryView pages are reachable by page rotor/scroll and each page reads as one combined element.",
        "Sweep Dynamic Type at xSmall, large, accessibility2, and accessibility3 for SummaryView, PetGlanceView, Settings, and About/settings text; confirm no clipping within each clamp.",
    )
    for item in checklist:
        reporter.manual_step(item)


def write_report(path: Path, reporter: Reporter, args: argparse.Namespace) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    status = "PASS" if not reporter.failures else "FAIL"
    lines = [
        "# M5-r4 App Store Readiness Verification Report",
        "",
        "Date: 2026-05-23 (UTC)",
        f"Static result: {status}",
        f"Archives requested: {'no' if args.static_only else 'yes'}",
        f"Manual checklist emitted: {'yes' if args.manual_checklist else 'no'}",
        "",
        "## Failures",
        "",
    ]
    if reporter.failures:
        lines.extend(f"- {failure.replace(chr(10), '<br>')}" for failure in reporter.failures)
    else:
        lines.append("- None")

    lines.extend(["", "## Warnings", ""])
    if reporter.warnings:
        lines.extend(f"- {warning}" for warning in reporter.warnings)
    else:
        lines.append("- None")

    lines.extend(["", "## Manual Checks", ""])
    if reporter.manual:
        lines.extend(f"- {step}" for step in reporter.manual)
    else:
        lines.append("- Not requested in this run")

    lines.extend([
        "",
        "## Commands",
        "",
        "```bash",
        "ci/verify_appstore_readiness.py --static-only",
        "ci/verify_appstore_readiness.py --require-xcodebuild --include-optional-archives --manual-checklist",
        "```",
        "",
    ])
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify Mochi M5-r4 App Store readiness assets, launch screen wiring, accessibility guardrails, and archives.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(
            """
            Examples:
              ci/verify_appstore_readiness.py --static-only
              ci/verify_appstore_readiness.py --require-xcodebuild --include-optional-archives --manual-checklist
            """
        ),
    )
    parser.add_argument("--static-only", action="store_true", help="Run Linux-compatible static checks only.")
    parser.add_argument("--include-optional-archives", action="store_true", help="Also archive Mochi watch container and complication schemes when present.")
    parser.add_argument("--require-xcodebuild", action="store_true", help="Fail if xcodebuild is unavailable.")
    parser.add_argument("--manual-checklist", action="store_true", help="Print manual simulator checks for launch, VoiceOver, and Dynamic Type.")
    parser.add_argument("--write-report", type=Path, help="Write a Markdown verification report to this path.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    os.chdir(Path(__file__).resolve().parents[1])
    args = parse_args(argv)
    reporter = Reporter.create()

    print("== Static M5-r4 App Store readiness checks ==")
    validate_static_project(reporter)

    if args.manual_checklist:
        print("== Manual simulator checklist ==")
        print_manual_checklist(reporter)

    if not args.static_only:
        print("== xcodebuild archive validation ==")
        run_archives(reporter, include_optional=args.include_optional_archives, require_xcodebuild=args.require_xcodebuild)

    if args.write_report:
        write_report(args.write_report, reporter, args)
        print(f"WROTE: {args.write_report}")

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
