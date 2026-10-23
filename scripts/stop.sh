#!/usr/bin/env bash
# Removes the demo container and the outputs `bazel run //plugin` and `bazel run //demo` recreate.
set -o errexit -o nounset -o pipefail

ROOT=${BUILD_WORKSPACE_DIRECTORY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh"

if docker container inspect "$NAME" > /dev/null 2>&1; then
  docker rm -f "$NAME" > /dev/null
  echo "Removed container $NAME"
fi
rm -rf "$ROOT/out" "$ROOT/plugin/target" "$ROOT/app/components"
