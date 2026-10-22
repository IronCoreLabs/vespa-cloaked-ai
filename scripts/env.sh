# shellcheck shell=bash disable=SC2034
# Sourced by the `bazel run` targets after they set ROOT to the repository root.

VESPA_VERSION=${VESPA_VERSION:-8.763.13}
IMAGE=${IMAGE:-vespa-jdk25:$VESPA_VERSION}
ALLOY_VERSION=${ALLOY_VERSION:-0.16.1}
