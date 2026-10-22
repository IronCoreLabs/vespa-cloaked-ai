#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

ROOT=${BUILD_WORKSPACE_DIRECTORY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh"

docker build --build-arg VESPA_VERSION="$VESPA_VERSION" \
  -t "$IMAGE" -f "$ROOT/build/Dockerfile" "$ROOT/build"
