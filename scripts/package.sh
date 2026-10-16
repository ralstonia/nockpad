#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Nockpad/Info.plist)
archive="Nockpad-${version}-universal-macOS.zip"
mkdir -p dist
xcodebuild -project Nockpad.xcodeproj -scheme Nockpad \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build
app='build/Build/Products/Release/Nockpad.app'
codesign --verify --deep --strict "$app"
lipo "$app/Contents/MacOS/Nockpad" -verify_arch arm64
lipo "$app/Contents/MacOS/Nockpad" -verify_arch x86_64
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > SHA256SUMS.txt)
print "Packaged dist/$archive"
