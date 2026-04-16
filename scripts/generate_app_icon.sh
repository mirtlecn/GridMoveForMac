#!/bin/zsh

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <app-name> <output-icns-path>" >&2
  exit 1
fi

app_name="$1"
output_path="$2"
iconset_path="${output_path:r}.iconset"

rm -rf "${iconset_path}" "${output_path}"
mkdir -p "${iconset_path}"

swift "./scripts/render_app_icon.swift" "${iconset_path}"
iconutil -c icns "${iconset_path}" -o "${output_path}"

rm -rf "${iconset_path}"

echo "app icon: ${output_path}"
