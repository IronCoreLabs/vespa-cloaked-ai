#!/usr/bin/env bash
# Runs stop.sh, then removes the Docker images and volume the builds create and Bazel's output base.
set -o errexit -o nounset -o pipefail

ROOT=${BUILD_WORKSPACE_DIRECTORY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh"

"$ROOT/scripts/stop.sh"

images=$(docker image ls --format '{{.Repository}}:{{.Tag}}' "$IMAGE_REPO")
for image in $images "$IMAGE" "$MAVEN_IMAGE"; do
  if docker image inspect "$image" > /dev/null 2>&1; then
    docker image rm "$image" > /dev/null
    echo "Removed image $image"
  fi
done

if docker volume inspect "$M2_VOLUME" > /dev/null 2>&1; then
  docker volume rm "$M2_VOLUME" > /dev/null
  echo "Removed volume $M2_VOLUME"
fi

cd "$ROOT"
bazel clean --expunge
