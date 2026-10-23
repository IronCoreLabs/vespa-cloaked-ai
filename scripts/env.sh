# shellcheck shell=bash disable=SC2034
# Sourced by the `bazel run` targets after they set ROOT to the repository root.

VESPA_VERSION=${VESPA_VERSION:-8.763.13}
IMAGE_REPO=${IMAGE_REPO:-vespa-jdk25}
IMAGE=${IMAGE:-$IMAGE_REPO:$VESPA_VERSION}
ALLOY_VERSION=${ALLOY_VERSION:-0.16.1}
NAME=${NAME:-vespa-cloaked-ai}
MAVEN_IMAGE=${MAVEN_IMAGE:-docker.io/maven:3-eclipse-temurin-25}
M2_VOLUME=${M2_VOLUME:-vespa-cloaked-ai-plugin-m2}
