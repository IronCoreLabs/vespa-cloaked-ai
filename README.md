# Cloaked AI in Vespa

An example of encrypting vector embeddings in [Vespa](https://vespa.ai) with [IronCore Cloaked AI](https://ironcorelabs.com/products/cloaked-ai/), using the standalone vector encryption in [ironcore-alloy](https://github.com/IronCoreLabs/ironcore-alloy) as a Vespa container plugin.

Documents are fed with plaintext vectors and stored encrypted. Queries carry a plaintext vector that is encrypted before it reaches the content nodes, so nearest neighbor search runs entirely on encrypted vectors. The Vespa nodes hold the key; the encrypted index on disk does not reveal the embeddings.

## Why a custom Vespa image

`ironcore-alloy-java` calls its native library through the Java FFM API. Its classes need JDK 22 or newer, and the bundled `libironcore_alloy.so` needs glibc 2.34 or newer. The default Vespa image runs AlmaLinux 8 (JDK 17, glibc 2.28).

This repo builds an image from the same published Vespa RPMs, using the AlmaLinux 9 packages (glibc 2.34) and running them on JDK 25 instead of the JDK 21 they are packaged with. Those jars target JDK 21 and contain no preview-feature class files, so they run on 25.

## Layout

| Path | Contents |
|---|---|
| `build/Dockerfile` | Vespa on AlmaLinux 9 with JDK 25, adapted from [vespa-engine/docker-image](https://github.com/vespa-engine/docker-image) |
| `plugin/` | The container plugin: `CloakedAi` component, `EncryptVectorsDocumentProcessor`, `EncryptQueryVectorSearcher` |
| `app/` | Vespa application package using the plugin |
| `demo/run-demo.sh` | Starts the image, deploys `app/`, feeds and queries |

## Requirements

- Docker

for this demo specifically:

- Bazel 8 (`.bazelversion` pins it for bazelisk; `nix develop` provides it)
- Vespa CLI (also provided by `nix develop` if you have it)

## Running

The Bazel targets are runners for Docker and Maven, so they are used with `bazel run`:

```sh
bazel run //build:image   # vespa-jdk25:<version>
bazel run //plugin        # app/components/cloaked-ai-vespa-plugin-deploy.jar
bazel run //demo
bazel run //:clean        # removes out/, plugin/target/ and app/components/
```

`VESPA_VERSION` (default `8.763.13`) selects the Vespa RPMs and the Vespa API the plugin is compiled against; `ALLOY_VERSION` (default `0.16.1`) selects `ironcore-alloy-java`. Pass them as environment variables, e.g. `VESPA_VERSION=8.763.13 bazel run //build:image`. The plugin build caches Maven downloads in the Docker volume `vespa-cloaked-ai-plugin-m2`.

The demo feeds six 8-dimensional vectors in three topics, then:

1. Fetches a stored document, showing the encrypted embedding and its `embedding_metadata`.
2. Queries with a plaintext vector near the fruit topic through the default chain, where the searcher encrypts it. Apple and banana rank first.
3. Sends the same query through the built-in `vespa` chain, which skips the searcher, to show that a plaintext query does not match against the encrypted index.
4. Shows that a partial update of `embedding` is rejected.

The container keeps running afterwards on ports 8080 and 19071.

## Trying it with the Vespa CLI

`nix develop` provides the `vespa` CLI (or install it from [the Vespa docs](https://docs.vespa.ai/en/vespa-cli.html)). Its default target is the local container the demo leaves running.

```sh
vespa status

# Feed a document with a plaintext vector; it is stored encrypted.
vespa document put id:demo:doc::violin \
  --data '{"fields": {"text": "violin", "embedding": {"values": [0.0, 0.1, 0.0, 0.0, 0.85, 0.85, 0.0, 0.1]}}}'
# See that the stored encrypted values are different than what was input
vespa document get id:demo:doc::violin

# Nearest neighbors of a plaintext query vector near the music topic.
vespa query 'yql=select text from doc where {targetHits: 3}nearestNeighbor(embedding, q)' \
  'input.query(q)=[0.05, 0.05, 0.05, 0.05, 0.85, 0.85, 0.05, 0.05]' ranking=closest hits=3

# The same query without EncryptQueryVectorSearcher, matching a plaintext vector against encrypted ones,
# violin's distance is too high to match.
vespa query 'yql=select text from doc where {targetHits: 3}nearestNeighbor(embedding, q)' \
  'input.query(q)=[0.05, 0.05, 0.05, 0.05, 0.85, 0.85, 0.05, 0.05]' ranking=closest hits=3 searchChain=vespa

# Rejected: partial updates of the encrypted field.
vespa document update id:demo:doc::violin --data '{"fields": {"embedding": {"assign": {"values": [1, 1, 1, 1, 1, 1, 1, 1]}}}}'

# Allowed: updates to other fields.
vespa document update id:demo:doc::violin --data '{"fields": {"text": {"assign": "fiddle"}}}'

vespa document remove id:demo:doc::violin
```

Query results include `matchfeatures` with the distance computed between the encrypted vectors.

## Using the plugin in your application

Add the jar to your application's `components/` directory, then wire it as in `app/services.xml`:

- One `CloakedAi` component, configured with `cloaked-ai` config (see `plugin/src/main/resources/configdefinitions/cloaked-ai.def`).
- `EncryptVectorsDocumentProcessor` in a document processing chain that inherits `indexing`, referenced from the content cluster.
- `EncryptQueryVectorSearcher` in the search chain your queries use.

The vector field must be a `tensor<float>(x[N])`, and the schema needs a `raw` field for the metadata returned by encryption, which is required to decrypt the vector.

The secret is read from a file holding at least 32 bytes, base64 encoded. The demo generates one and mounts it at `/run/secrets/cloaked-ai-secret`; in production, provision it the way you provision other secrets on Vespa nodes. Every container node that feeds or queries needs the same secret, tenant id and approximation factor.

The plugin copies `libironcore_alloy.so` from the alloy jar to a temporary file at startup and loads it from there. It supports Linux on x86-64 and aarch64.
