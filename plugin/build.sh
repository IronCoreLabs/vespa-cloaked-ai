#!/usr/bin/env bash
# Builds the plugin with Maven in Docker and copies it into the demo application package.
set -o errexit -o nounset -o pipefail

ROOT=${BUILD_WORKSPACE_DIRECTORY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh"

docker run --rm \
  -v "$ROOT/plugin:/plugin" -w /plugin \
  -v vespa-cloaked-ai-plugin-m2:/root/.m2 \
  docker.io/maven:3-eclipse-temurin-25 \
  mvn --batch-mode -Dvespa.version="$VESPA_VERSION" -Dalloy.version="$ALLOY_VERSION" package
mkdir -p "$ROOT/app/components"
cp "$ROOT/plugin/target/cloaked-ai-vespa-plugin-deploy.jar" "$ROOT/app/components/"
