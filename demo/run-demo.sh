#!/usr/bin/env bash
# Starts Vespa from $IMAGE, deploys ./app with the Cloaked AI plugin, feeds demo/docs.jsonl and queries it.
set -o errexit -o nounset -o pipefail

ROOT=${BUILD_WORKSPACE_DIRECTORY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh"
NAME=${NAME:-vespa-cloaked-ai}
WORK=$ROOT/out/demo

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
vespa() { docker exec "$NAME" vespa "$@"; }

test -f "$ROOT/app/components/cloaked-ai-vespa-plugin-deploy.jar" || { echo "Run 'bazel run //plugin' first" >&2; exit 1; }

step "Generating a Cloaked AI secret"
mkdir -p "$WORK"
head -c 32 /dev/urandom | base64 > "$WORK/secret"
chmod 644 "$WORK/secret"

step "Starting $IMAGE"
docker rm -f "$NAME" > /dev/null 2>&1 || true
docker run --detach --name "$NAME" --hostname "$NAME" \
  --publish 8080:8080 --publish 19071:19071 \
  --volume "$ROOT/app:/app:ro" \
  --volume "$ROOT/demo:/demo:ro" \
  --volume "$WORK/secret:/run/secrets/cloaked-ai-secret:ro" \
  "$IMAGE" > /dev/null
docker exec "$NAME" bash -c 'java -version 2>&1 | head -1; ldd --version | head -1'

step "Deploying the application package"
vespa status deploy --wait 300
vespa deploy --wait 300 /app
vespa status --wait 300

step "Feeding plaintext vectors"
vespa feed /demo/docs.jsonl

step "Stored embedding for 'apple' (fed as [0.9, 0.8, 0.1, 0.0, 0.1, 0.0, 0.0, 0.1])"
vespa document get id:demo:doc::apple

near_fruit='[0.85, 0.85, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]'
yql='select text from doc where {targetHits: 6}nearestNeighbor(embedding, q)'

step "Plaintext query near 'fruit', encrypted by EncryptQueryVectorSearcher"
encrypted_result=$(vespa query "yql=$yql" "input.query(q)=$near_fruit" ranking=closest hits=6)
echo "$encrypted_result"

step "Same query sent without the searcher (searchChain=vespa): plaintext query against encrypted vectors"
vespa query "yql=$yql" "input.query(q)=$near_fruit" ranking=closest hits=6 searchChain=vespa

step "Updating the encrypted field is rejected"
if update_output=$(vespa document update /demo/update-embedding.json 2>&1); then
  echo "FAIL: update of the encrypted field was accepted" >&2
  exit 1
fi
echo "$update_output"
if [[ $update_output != *"are not supported; put the whole document"* ]]; then
  echo "FAIL: update failed for another reason than EncryptVectorsDocumentProcessor rejecting it" >&2
  exit 1
fi

step "Checking the encrypted search ranks the fruit documents first"
top_two=$(echo "$encrypted_result" | grep -oE '"text": "[a-z]+"' | head -2 | sort | tr '\n' ' ')
if [[ $top_two != '"text": "apple" "text": "banana" ' ]]; then
  echo "FAIL: expected apple and banana as the top two hits, got: $top_two" >&2
  exit 1
fi
echo "OK: top two hits are apple and banana"
echo "Vespa is still running as container '$NAME'; remove it with: docker rm -f $NAME"
