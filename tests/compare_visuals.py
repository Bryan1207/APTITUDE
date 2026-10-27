#!/usr/bin/env python3
"""Compare new APTITUDE GUI screenshots with human-approved baselines.

First run has no baselines. It reports "awaiting approval" rather than
silently treating arbitrary screenshots as correct. Approve only reviewed
screenshots by adding selected PNGs to tests/visual_baselines/.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from PIL import Image, ImageChops


def compare(current_path: Path, baseline_path: Path, diff_dir: Path, max_changed_percent: float) -> dict:
    with Image.open(current_path) as current_file, Image.open(baseline_path) as baseline_file:
        current = current_file.convert("RGB")
        baseline = baseline_file.convert("RGB")

    record = {"image": current_path.name, "status": "passed"}
    if current.size != baseline.size:
        record.update(status="failed", reason=f"image size {current.size} differs from approved {baseline.size}")
        return record

    difference = ImageChops.difference(current, baseline)
    channels = difference.split()
    max_channel = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])
    # Ignore tiny font anti-aliasing or GPU rounding differences.
    significant = max_channel.point(lambda value: 255 if value >= 40 else 0)
    histogram = significant.histogram()
    changed_pixels = histogram[255]
    changed_percent = 100.0 * changed_pixels / (current.width * current.height)
    record.update(changed_percent=round(changed_percent, 3), max_allowed_percent=max_changed_percent)
    if changed_percent > max_changed_percent:
        record["status"] = "failed"
        record["reason"] = "visual change exceeds approved threshold"
        diff_dir.mkdir(parents=True, exist_ok=True)
        highlighted = Image.blend(current, Image.new("RGB", current.size, (255, 30, 40)), 0.6)
        current.paste(highlighted, (0, 0), significant)
        output = diff_dir / current_path.name
        current.save(output)
        record["diff_image"] = str(output)
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--screenshots", type=Path, required=True)
    parser.add_argument("--baselines", type=Path, required=True)
    parser.add_argument("--diffs", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--max-changed-percent", type=float, default=3.0)
    args = parser.parse_args()

    captures = sorted(args.screenshots.glob("*.png"))
    approved = {p.name: p for p in args.baselines.glob("*.png")}
    records = []
    failure = False
    if not captures:
        records.append({"status": "failed", "reason": "no graphical screenshots were captured"})
        failure = True
    for capture in captures:
        if capture.name not in approved:
            records.append({"image": capture.name, "status": "awaiting_approval"})
        else:
            result = compare(capture, approved[capture.name], args.diffs, args.max_changed_percent)
            records.append(result)
            if result["status"] == "failed":
                failure = True
    for missing_name in sorted(approved.keys() - {p.name for p in captures}):
        records.append({"image": missing_name, "status": "failed", "reason": "approved screenshot was not captured"})
        failure = True

    result = {
        "passed": not failure,
        "screenshots": len(captures),
        "approved_baselines": len(approved),
        "results": records,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    lines = ["### APTITUDE graphical screenshots", ""]
    lines += ["| Screenshot | Result | Changed pixels |", "|---|---|---|"]
    for record in records:
        lines.append("| {image} | {status} | {changed} |".format(
            image=record.get("image", "(none)"),
            status=record["status"],
            changed=("%s%%" % record["changed_percent"]) if "changed_percent" in record else "—",
        ))
    summary = "\n".join(lines) + "\n"
    print(summary)
    print("Comparison report:", args.report)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
            stream.write(summary)
    if not approved:
        print("NOTE: No approved baselines yet. Inspect the screenshot artifact, then approve selected PNGs in tests/visual_baselines.")
    return 1 if failure else 0


if __name__ == "__main__":
    raise SystemExit(main())
