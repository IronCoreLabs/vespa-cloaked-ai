#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

ROOT=${BUILD_WORKSPACE_DIRECTORY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
rm -rf "$ROOT/out" "$ROOT/plugin/target" "$ROOT/app/components"
