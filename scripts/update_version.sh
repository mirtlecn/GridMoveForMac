#!/bin/zsh

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version-file> <version>" >&2
  exit 1
fi

version_file="$1"
raw_version="$2"
normalized_version="${raw_version#v}"
normalized_version="${normalized_version#V}"

if [[ ! "${normalized_version}" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
  echo "invalid version: ${raw_version}" >&2
  echo "expected format: v0.1.1 or 0.1.1" >&2
  exit 1
fi

printf '%s\n' "${normalized_version}" > "${version_file}"
echo "updated version: ${normalized_version}"
