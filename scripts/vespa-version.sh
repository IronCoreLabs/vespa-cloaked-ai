#!/usr/bin/env bash
# Prints the Vespa release version (X.Y.Z) for a ref that is exactly a vX.Y.Z tag.
set -o errexit -o nounset -o pipefail

src=$1
ref=$2
tag=$(git -C "$src" describe --tags --exact-match --match 'v[0-9]*.[0-9]*.[0-9]*' "$ref" 2>/dev/null) || {
  echo "$ref in $src is not a vX.Y.Z release tag; check one out or set VESPA_VERSION" >&2
  exit 1
}
echo "${tag#v}"
