#!/bin/bash
# Build trên Mac + Xcode (không Theos cũng được)
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/../packages"
mkdir -p "$OUT"
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
clang -dynamiclib -fobjc-arc \
  -isysroot "$SDK" \
  -arch arm64 -arch arm64e \
  -miphoneos-version-min=14.0 \
  -framework UIKit -framework AVFoundation \
  -framework Foundation -framework UserNotifications \
  -install_name @rpath/Zalo2KeepAlive.dylib \
  -o "$OUT/Zalo2KeepAlive.dylib" \
  "$ROOT/Zalo2KeepAlive.m"
codesign -f -s - "$OUT/Zalo2KeepAlive.dylib" 2>/dev/null || true
lipo -info "$OUT/Zalo2KeepAlive.dylib"
cd "$OUT" && zip -j Zalo2KeepAlive-TrollFools.zip Zalo2KeepAlive.dylib
echo "OK: $OUT/Zalo2KeepAlive.dylib"
echo "TrollFools → Zalo2 → Inject → file dylib này"
