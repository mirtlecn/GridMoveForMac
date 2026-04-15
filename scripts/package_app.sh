#!/bin/zsh

set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "usage: $0 <app-name> <app-bundle-path> <bundle-id> <version> <build-number> <sign-identity>" >&2
  exit 1
fi

app_name="$1"
app_bundle_path="$2"
bundle_id="$3"
version="$4"
build_number="$5"
sign_identity="$6"

release_binary=".build/release/${app_name}"
contents_path="${app_bundle_path}/Contents"
macos_path="${contents_path}/MacOS"
resources_path="${contents_path}/Resources"
plist_path="${contents_path}/Info.plist"
zip_path="${app_bundle_path:r}.zip"

if [[ ! -x "${release_binary}" ]]; then
  echo "missing release binary: ${release_binary}" >&2
  exit 1
fi

rm -rf "${app_bundle_path}" "${zip_path}"
mkdir -p "${macos_path}" "${resources_path}"

cp "${release_binary}" "${macos_path}/${app_name}"

cat > "${plist_path}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${app_name}</string>
  <key>CFBundleExecutable</key>
  <string>${app_name}</string>
  <key>CFBundleIdentifier</key>
  <string>${bundle_id}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${app_name}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${version}</string>
  <key>CFBundleVersion</key>
  <string>${build_number}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

printf 'APPL????' > "${contents_path}/PkgInfo"

plutil -lint "${plist_path}" >/dev/null

codesign --force --deep --sign "${sign_identity}" --timestamp=none "${app_bundle_path}"
codesign --verify --deep --strict --verbose=2 "${app_bundle_path}"

ditto -c -k --sequesterRsrc --keepParent "${app_bundle_path}" "${zip_path}"

echo "app bundle: ${app_bundle_path}"
echo "zip archive: ${zip_path}"
