#!/bin/bash
# 署名なしでビルドした .app から、Sideloadly / AltStore で署名し直せる .ipa を作る。
#
# 使い方: scripts/package-ipa.sh <KeyFlow.app> <出力.ipa> <App Group ID>
#
# 署名ツールはアプリに埋め込まれた権限情報（entitlements）を見て、無料アカウントでも
# App Group などを登録する。署名なしのままだと権限情報が無いので、
# ここでアドホック署名をして App Group の権限を埋め込んでおく。
set -euo pipefail

APP_PATH="$1"
OUT_PATH="$2"
APP_GROUP="$3"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Payload"
cp -R "$APP_PATH" "$WORK/Payload/"
APP="$WORK/Payload/$(basename "$APP_PATH")"

ENTITLEMENTS="$WORK/entitlements.plist"
cat > "$ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>${APP_GROUP}</string>
	</array>
</dict>
</plist>
PLIST

# 内側（拡張・フレームワーク）から順に署名する
if [ -d "$APP/Frameworks" ]; then
  find "$APP/Frameworks" -maxdepth 1 \( -name "*.framework" -o -name "*.dylib" \) -print0 | while IFS= read -r -d '' f; do
    codesign --force --sign - --timestamp=none "$f"
  done
fi
for appex in "$APP"/PlugIns/*.appex; do
  [ -d "$appex" ] || continue
  codesign --force --sign - --timestamp=none --entitlements "$ENTITLEMENTS" "$appex"
done
codesign --force --sign - --timestamp=none --entitlements "$ENTITLEMENTS" "$APP"

echo "== entitlements (app)"
codesign -d --entitlements - "$APP" 2>/dev/null || true
for appex in "$APP"/PlugIns/*.appex; do
  echo "== entitlements ($(basename "$appex"))"
  codesign -d --entitlements - "$appex" 2>/dev/null || true
  echo "== Info.plist ($(basename "$appex"))"
  plutil -p "$appex/Info.plist" | grep -E "CFBundleIdentifier|NSExtensionPointIdentifier|RequestsOpenAccess|KeyFlowAppGroup" || true
done

rm -f "$OUT_PATH"
(cd "$WORK" && zip -qry "$OUT_PATH" Payload)
echo "== sizes"
du -sh "$APP" "$APP"/PlugIns/*.appex "$OUT_PATH"
