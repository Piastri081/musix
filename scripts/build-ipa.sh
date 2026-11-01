#!/usr/bin/env bash
# Build an unsigned Musix.ipa on macOS.
# Usage: ./scripts/build-ipa.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/ios"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen…"
  brew install xcodegen
fi

echo "Generating Xcode project…"
xcodegen generate

echo "Building (Release, unsigned)…"
xcodebuild \
  -project Musix.xcodeproj \
  -scheme Musix \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

echo "Packaging IPA…"
rm -rf out
mkdir -p out/Payload
cp -R build/Build/Products/Release-iphoneos/Musix.app out/Payload/
(cd out && zip -qry Musix.ipa Payload)
shasum -a 256 out/Musix.ipa | tee out/Musix.ipa.sha256

echo
echo "Done: $ROOT/ios/out/Musix.ipa"
