#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
edition="${1:-original}"
case "$edition" in
  original) version=0.1.0; product=Nockpad; identifier=app.nockpad.mac ;;
  return) version=0.2.0; product='Nockpad Return'; identifier=app.nockpad.mac.return ;;
  quiet) version=0.3.0; product='Nockpad Quiet'; identifier=app.nockpad.mac.quiet ;;
  fieldnotes) version=0.4.0; product='Nockpad Fieldnotes'; identifier=app.nockpad.mac.fieldnotes ;;
  rhythm) version=0.5.0; product='Nockpad Rhythm'; identifier=app.nockpad.mac.rhythm ;;
  *) print -u2 'Choose original, return, quiet, fieldnotes, or rhythm'; exit 2 ;;
esac
archive="Nockpad-${version}-${edition}-universal-macOS.zip"
mkdir -p dist
xcodebuild -project Nockpad.xcodeproj -scheme Nockpad \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "build/$edition" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  "PRODUCT_NAME=$product" "PRODUCT_BUNDLE_IDENTIFIER=$identifier" \
  "NOCKPAD_EDITION=$edition" "MARKETING_VERSION=$version" build
app="build/$edition/Build/Products/Release/$product.app"
codesign --verify --deep --strict "$app"
lipo "$app/Contents/MacOS/$product" -verify_arch arm64
lipo "$app/Contents/MacOS/$product" -verify_arch x86_64
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NockpadEdition' "$app/Contents/Info.plist")" == "$edition" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" == "$identifier" ]]
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > "${archive%.zip}.sha256")
print "Packaged dist/$archive"
