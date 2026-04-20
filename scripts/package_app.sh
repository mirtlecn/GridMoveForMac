#!/bin/zsh

set -euo pipefail

if [[ $# -ne 9 ]]; then
  echo "usage: $0 <app-name> <app-bundle-path> <bundle-id> <version> <build-number> <sign-identity> <author-name> <author-url> <version-info>" >&2
  exit 1
fi

app_name="$1"
app_bundle_path="$2"
bundle_id="$3"
version="$4"
build_number="$5"
sign_identity="$6"
author_name="$7"
author_url="$8"
version_info="$9"

release_binary=".build/release/${app_name}"
contents_path="${app_bundle_path}/Contents"
macos_path="${contents_path}/MacOS"
resources_path="${contents_path}/Resources"
plist_path="${contents_path}/Info.plist"
dmg_path="${app_bundle_path:r}.dmg"
staging_root="${app_bundle_path:h}/.dmg-staging"
staging_path="${staging_root}/${app_name}"
icon_path="${resources_path}/AppIcon.icns"
static_icon_path="Sources/GridMove/Resources/AppIcon.icns"
source_resources_path="Sources/GridMove/Resources"
release_resources_root=".build/release"

if [[ ! -x "${release_binary}" ]]; then
  echo "missing release binary: ${release_binary}" >&2
  exit 1
fi

rm -rf "${app_bundle_path}" "${dmg_path}" "${staging_root}"
mkdir -p "${macos_path}" "${resources_path}"

cp "${release_binary}" "${macos_path}/${app_name}"

if [[ -f "${static_icon_path}" ]]; then
  cp "${static_icon_path}" "${icon_path}"
else
  zsh "$(dirname "$0")/generate_app_icon.sh" "${app_name}" "${icon_path}"
fi

if [[ -d "${source_resources_path}" ]]; then
  for localization_path in "${source_resources_path}"/*.lproj; do
    [[ -d "${localization_path}" ]] || continue
    cp -R "${localization_path}" "${resources_path}/$(basename "${localization_path}")"
  done
fi

if [[ -d "${release_resources_root}" ]]; then
  for resource_bundle in "${release_resources_root}"/*.bundle; do
    [[ -d "${resource_bundle}" ]] || continue
    cp -R "${resource_bundle}" "${resources_path}/$(basename "${resource_bundle}")"
  done
fi

cat > "${plist_path}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
  </array>
  <key>CFBundleDisplayName</key>
  <string>${app_name}</string>
  <key>CFBundleExecutable</key>
  <string>${app_name}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${bundle_id}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleGetInfoString</key>
  <string>${app_name} ${version_info}</string>
  <key>GridMoveDisplayVersion</key>
  <string>${version_info}</string>
  <key>CFBundleName</key>
  <string>${app_name}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${version}</string>
  <key>CFBundleVersion</key>
  <string>${build_number}</string>
  <key>NSHumanReadableCopyright</key>
  <string>Created by ${author_name} (${author_url})</string>
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

mkdir -p "${staging_path}"
cp -R "${app_bundle_path}" "${staging_path}/${app_name}.app"
ln -s /Applications "${staging_path}/Applications"

hdiutil create \
  -volname "${app_name}" \
  -srcfolder "${staging_path}" \
  -ov \
  -format UDZO \
  "${dmg_path}" >/dev/null

rm -rf "${staging_root}"

echo "app bundle: ${app_bundle_path}"
echo "disk image: ${dmg_path}"
