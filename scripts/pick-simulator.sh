#!/bin/bash
# 使える iPhone シミュレーターを1台選び、xcodebuild の -destination 用の文字列を出力する。
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    if "iOS" not in runtime:
        continue
    for d in devices:
        if d["name"].startswith("iPhone") and "Pro" not in d["name"] and "Plus" not in d["name"] and "Max" not in d["name"]:
            version = runtime.rsplit("iOS-", 1)[-1]
            key = tuple(int(x) for x in version.split("-") if x.isdigit())
            if best is None or key > best[0]:
                best = (key, d["udid"], d["name"])
if best is None:
    sys.exit("no iPhone simulator")
print(f"platform=iOS Simulator,id={best[1]}")
print(best[2], file=sys.stderr)
'
