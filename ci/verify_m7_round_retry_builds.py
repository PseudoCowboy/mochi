#!/usr/bin/env python3
"""Verify the M7 Round C retry build matrix.

Static checks run on any host. Passing ``--require-xcodebuild`` additionally
runs the requested Xcode build and build-for-testing matrix against simulator
destinations and fails if Xcode is unavailable.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

PROJECT = Path("Mochi.xcodeproj")
SCHEME_DIR = PROJECT / "xcshareddata" / "xcschemes"
DERIVED_DATA = Path("build/m7-round-retry-derived-data")

MATRIX = (
    ("Mochi Watch App", "generic/platform=watchOS Simulator"),
    ("Mochi iOS", "generic/platform=iOS Simulator"),
    ("Mochi Complication", "generic/platform=watchOS Simulator"),
    ("Mochi Watch AppTests", "generic/platform=watchOS Simulator"),
    ("Mochi iOSTests", "generic/platform=iOS Simulator"),
)
ACTIONS = ("build", "build-for-testing")

SCOPED_FILES = (
    Path("Mochi iOSTests/SummaryWriterBGTaskIntegrationTests.swift"),
    Path("Mochi iOSTests/Support/BGTaskFakes.swift"),
    Path("Mochi Watch AppTests/HeartRateServiceObserverWiringTests.swift"),
    Path("Mochi Watch AppTests/StressNotifierObserverSmokeTests.swift"),
    Path("Mochi Watch AppTests/Support/HKHealthStoreFake.swift"),
)
FORBIDDEN_TEST_TOKENS = (
    "BGTaskScheduler.shared",
    "HKHealthStore(",
    "Date(",
    "Timer.publish",
    "sleep(",
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


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def scheme_file(scheme: str) -> Path:
    return SCHEME_DIR / f"{scheme}.xcscheme"


def static_checks() -> list[Check]:
    checks: list[Check] = []

    if PROJECT.is_dir():
        checks.append(Check("Xcode project exists", "PASS", str(PROJECT)))
    else:
        checks.append(Check("Xcode project exists", "FAIL", str(PROJECT)))

    for scheme, _ in MATRIX:
        path = scheme_file(scheme)
        if not path.is_file():
            checks.append(Check(f"Shared scheme {scheme}", "FAIL", "missing"))
            continue
        try:
            ET.parse(path)
        except ET.ParseError as error:
            checks.append(Check(f"Shared scheme {scheme}", "FAIL", str(error)))
        else:
            checks.append(Check(f"Shared scheme {scheme}", "PASS", path.name))

    project_file = PROJECT / "project.pbxproj"
    project_text = project_file.read_text(encoding="utf-8") if project_file.is_file() else ""
    for root in ("Mochi iOSTests", "Mochi Watch AppTests"):
        token = f"path = \"{root}\";" if " " in root else f"path = {root};"
        status = "PASS" if token in project_text else "FAIL"
        checks.append(Check(f"{root} synchronized test root", status, token))

    stale_refs = ("Fakes+BGTaskScheduler.swift", "Fakes+HealthKit.swift")
    stale = [token for token in stale_refs if token in project_text]
    checks.append(Check("No stale shared fake PBX refs", "PASS" if not stale else "FAIL", ", ".join(stale)))

    for path in SCOPED_FILES:
        if path.is_file():
            checks.append(Check(f"Scoped file {path}", "PASS"))
        else:
            checks.append(Check(f"Scoped file {path}", "FAIL", "missing"))

    forbidden_hits: list[str] = []
    for path in SCOPED_FILES:
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for token in FORBIDDEN_TEST_TOKENS:
            if token in text:
                forbidden_hits.append(f"{path}: {token}")
    checks.append(Check(
        "Scoped tests avoid real framework/time seams",
        "PASS" if not forbidden_hits else "FAIL",
        "; ".join(forbidden_hits),
    ))

    diff = run(["git", "diff", "--check"])
    checks.append(Check("git diff --check", "PASS" if diff.returncode == 0 else "FAIL", diff.stdout.strip()))

    return checks


def build_matrix(require_xcodebuild: bool) -> list[BuildResult]:
    xcodebuild = shutil.which("xcodebuild")
    if not xcodebuild:
        status = "FAIL" if require_xcodebuild else "SKIP"
        return [
            BuildResult(scheme, action, destination, status, "xcodebuild unavailable")
            for scheme, destination in MATRIX
            for action in ACTIONS
        ]

    results: list[BuildResult] = []
    for scheme, destination in MATRIX:
        for action in ACTIONS:
            derived_data = DERIVED_DATA / scheme.replace(" ", "_") / action
            command = [
                xcodebuild,
                "-project",
                str(PROJECT),
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


def render_markdown(checks: list[Check], builds: list[BuildResult], require_xcodebuild: bool) -> str:
    lines = [
        "# M7 Round C Retry Build Report",
        "",
        "Date: 2026-05-22 (UTC)",
        "Host: Linux-compatible static checks; Mac/Xcode required for simulator builds",
        "Branch: `mythos/m7-tests-r1`",
        "",
        "## Static checks",
        "",
        "| Check | Result | Detail |",
        "| --- | --- | --- |",
    ]
    for check in checks:
        detail = check.detail.replace("|", "\\|") if check.detail else ""
        lines.append(f"| {check.name} | {check.status} | {detail} |")

    lines.extend([
        "",
        "## xcodebuild matrix",
        "",
        "| Scheme | Action | Destination | Result | Detail |",
        "| --- | --- | --- | --- | --- |",
    ])
    for build in builds:
        detail = build.detail.replace("|", "\\|").replace("\n", "<br>") if build.detail else ""
        lines.append(f"| `{build.scheme}` | `{build.action}` | `{build.destination}` | {build.status} | {detail} |")

    skip_details = {build.detail for build in builds if build.status == "SKIP"}
    if "static-only run" in skip_details:
        lines.extend([
            "",
            "Local note: this was a static-only run, so simulator builds were intentionally skipped.",
        ])
    elif any(build.status == "SKIP" for build in builds):
        lines.extend([
            "",
            "Local note: `xcodebuild` is unavailable on this host, so simulator builds were not run locally. Run `python3 ci/verify_m7_round_retry_builds.py --require-xcodebuild --write-report ci/m7_round_retry_build_report.md` on the Mac-side watcher to populate PASS/FAIL results.",
        ])
    elif require_xcodebuild:
        lines.extend(["", "Local note: `xcodebuild` was required for this run."])

    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-xcodebuild", action="store_true", help="fail when xcodebuild is unavailable")
    parser.add_argument("--static-only", action="store_true", help="skip xcodebuild even if available")
    parser.add_argument("--write-report", type=Path, help="write a Markdown report to this path")
    args = parser.parse_args()

    checks = static_checks()
    builds = [] if args.static_only else build_matrix(args.require_xcodebuild)

    if args.static_only:
        builds = [
            BuildResult(scheme, action, destination, "SKIP", "static-only run")
            for scheme, destination in MATRIX
            for action in ACTIONS
        ]

    report = render_markdown(checks, builds, args.require_xcodebuild)
    if args.write_report:
        args.write_report.parent.mkdir(parents=True, exist_ok=True)
        args.write_report.write_text(report, encoding="utf-8")
    print(report)

    failed_checks = [check for check in checks if check.status == "FAIL"]
    failed_builds = [build for build in builds if build.status == "FAIL"]
    return 1 if failed_checks or failed_builds else 0


if __name__ == "__main__":
    sys.exit(main())
