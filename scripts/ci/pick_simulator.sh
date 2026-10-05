#!/usr/bin/env bash
# CI'daki Xcode surumunde mevcut olan en yeni iOS runtime'indaki ilk iPhone simulatorunun UDID'sini yazar.
# Cihaz adi sabitlenmez (or. "iPhone 15"), cunku Xcode surumu degistikce mevcut simulatorler degisir.
set -euo pipefail

xcrun simctl list devices available --json | python3 -c '
import json, re, sys
data = json.load(sys.stdin)["devices"]

def version(runtime):
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)

ios = sorted((r for r in data if "iOS" in r), key=version, reverse=True)
for runtime in ios:
    for device in data[runtime]:
        if device["name"].startswith("iPhone") and device.get("isAvailable", True):
            print(device["udid"])
            sys.exit(0)
sys.exit("Uygun iPhone simulatoru bulunamadi")
'
