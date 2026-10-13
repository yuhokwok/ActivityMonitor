#!/usr/bin/env python3
"""Run the real Home Widget entry model on macOS without launching WidgetKit.

The Swift model is extracted verbatim from the widget source, with a minimal
TimelineEntry protocol stub. No second implementation of its behavior is kept.
"""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Widget" / "MonitorHomeWidget.swift"
OUTPUT = ROOT / "Validation" / "home-widget-model.txt"

SWIFT_CHECKS = r'''
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("FAIL: \(message)") }
    checks += 1
    print("PASS: \(message)")
}

let captured = Date(timeIntervalSince1970: 1_700_000_000)
func entry(total: Int64? = 1_000, available: Int64? = 250) -> MonitorHomeEntry {
    MonitorHomeEntry(date: captured, lastUpdated: captured,
                     batteryLevel: 0.68, batteryState: "charging", thermalState: "fair",
                     storageTotalBytes: total, storageAvailableBytes: available,
                     isPreview: false)
}
let measured = entry()
check(!measured.isStale(at: captured.addingTimeInterval(3599)), "Sample is fresh at 3,599 seconds")
check(measured.isStale(at: captured.addingTimeInterval(3600)), "Sample becomes stale at 3,600 seconds")
let fallback = measured.staleEntry()
check(fallback.date == captured.addingTimeInterval(3600), "Fallback is scheduled at the one-hour threshold")
check(fallback.lastUpdated == captured, "Fallback retains the original capture timestamp")
check(fallback.isStale(at: captured), "Fallback is stale even when WidgetKit renders it early")
check(fallback.batteryLevel == measured.batteryLevel && fallback.batteryState == measured.batteryState,
      "Fallback does not fabricate a new battery measurement")
check(fallback.thermalState == measured.thermalState,
      "Fallback does not fabricate a new thermal measurement")
check(fallback.storageTotalBytes == measured.storageTotalBytes && fallback.storageAvailableBytes == measured.storageAvailableBytes,
      "Fallback does not fabricate a new storage measurement")
check(!fallback.isPreview, "Real fallback remains a real captured sample")
let missing = MonitorHomeEntry(date: captured, lastUpdated: captured, batteryLevel: nil,
                              batteryState: "unknown", thermalState: "unknown",
                              storageTotalBytes: nil, storageAvailableBytes: nil, isPreview: false)
check(missing.staleEntry().batteryLevel == nil && missing.staleEntry().batteryState == "unknown",
      "Unavailable battery remains unavailable in the fallback")
check(missing.storageUsedBytes == nil && missing.storageUsedFraction == nil,
      "Unavailable storage does not become zero usage")
check(measured.storageUsedBytes == 750 && measured.storageUsedFraction == 0.75,
      "Valid capacities produce the expected used bytes and fraction")
check(entry(total: nil).storageUsedBytes == nil && entry(available: nil).storageUsedFraction == nil,
      "Partial storage data remains unavailable")
check(entry(available: -1).storageUsedBytes == nil && entry(available: -1).storageUsedFraction == nil,
      "Negative available capacity is rejected")
check(entry(total: -1).storageUsedBytes == nil && entry(total: -1).storageUsedFraction == nil,
      "Negative total capacity is rejected")
check(entry(available: 1_200).storageUsedBytes == 0 && entry(available: 1_200).storageUsedFraction == 0,
      "Available capacity above total is bounded")
check(entry(available: 0).storageUsedBytes == 1_000 && entry(available: 0).storageUsedFraction == 1,
      "Full storage reaches the upper bound")
check(entry(total: 0, available: 0).storageUsedBytes == 0 && entry(total: 0, available: 0).storageUsedFraction == nil,
      "Zero total capacity cannot divide by zero")
let preview = MonitorHomeEntry.preview(at: captured)
check(preview.isPreview && !preview.isStale(at: captured.addingTimeInterval(7200)),
      "Gallery fixture is explicitly preview data")
var configured = measured
configured.displayedMetrics = ["memory", "storage"]
configured.systemMemoryUsedBytes = 700
configured.physicalMemoryBytes = 1_000
let configuredFallback = configured.staleEntry()
check(configuredFallback.displayedMetrics == ["memory", "storage"], "Stale entry retains configured metric order")
check(configuredFallback.systemMemoryUsedBytes == 700 && configuredFallback.physicalMemoryBytes == 1_000,
      "Stale entry retains original system RAM sample")
check(configuredFallback.lastUpdated == captured, "Configured stale entry cannot imply a new capture")
check(missing.staleEntry().systemMemoryUsedBytes == nil, "Missing system RAM stays unavailable")
print("Swift model checks passed: \(checks)")
'''


def verify() -> tuple[int, str]:
    source = SOURCE.read_text(encoding="utf-8")
    start = source.index("struct MonitorHomeEntry: TimelineEntry {")
    end = source.index("\nstruct MonitorHomeProvider:", start)
    model = source[start:end]
    required = [
        (r"requestedRefreshInterval:\s*TimeInterval\s*=\s*30\s*\*\s*60\b",
         "Provider requests a 30-minute reload interval"),
        (r"policy:\s*\.after\(entry\.date\.addingTimeInterval\(Self\.requestedRefreshInterval\)\)",
         "Provider applies the interval using an after policy"),
        (r"entries:\s*\[entry,\s*entry\.staleEntry\(\)\]",
         "Timeline contains the captured sample and its stale fallback"),
    ]
    log = ["Home Widget model verification", "Source: Widget/MonitorHomeWidget.swift"]
    for pattern, label in required:
        if not re.search(pattern, source):
            return 1, "\n".join(log + ["FAIL: " + label]) + "\n"
        log.append("PASS: " + label)
    harness = "import Foundation\nprotocol TimelineEntry { var date: Date { get } }\n" + model + SWIFT_CHECKS
    with tempfile.TemporaryDirectory(prefix="activity-monitor-home-model-") as directory:
        path = Path(directory) / "HomeWidgetModelChecks.swift"
        path.write_text(harness, encoding="utf-8")
        result = subprocess.run(["xcrun", "swift", str(path)], cwd=ROOT,
                                capture_output=True, text=True, timeout=60)
    log.append(result.stdout.rstrip())
    if result.stderr.strip():
        log.append(result.stderr.rstrip())
    log.append("RESULT: PASS" if result.returncode == 0 else "RESULT: FAIL")
    return result.returncode, "\n".join(log) + "\n"


if __name__ == "__main__":
    try:
        status, report = verify()
    except Exception as error:
        status, report = 1, f"Home Widget model verification\nRESULT: FAIL\n{error}\n"
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(report, encoding="utf-8")
    print(report, end="")
    raise SystemExit(status)
