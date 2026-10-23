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
bazel run //:stop         # removes the demo container, out/, plugin/target/ and app/components/
bazel run //:clean        # stop, then removes the images, the Maven cache volume and Bazel's output
```

`VESPA_VERSION` (default `8.763.13`) selects the Vespa RPMs and the Vespa API the plugin is compiled against; `ALLOY_VERSION` (default `0.16.1`) selects `ironcore-alloy-java`. Pass them as environment variables, e.g. `VESPA_VERSION=8.763.13 bazel run //build:image`. The plugin build caches Maven downloads in the Docker volume `vespa-cloaked-ai-plugin-m2`.

The demo feeds six 8-dimensional vectors in three topics, then:

1. Fetches a stored document, showing the encrypted embedding and its `embedding_metadata`.
2. Queries with a plaintext vector near the fruit topic through the default chain, where the searcher encrypts it. Apple and banana rank first.
3. Sends the same query through the built-in `vespa` chain, which skips the searcher, to show that a plaintext query does not match against the encrypted index.
4. Shows that a partial update of `embedding` is rejected.

The container keeps running afterwards on ports 8080 and 19071, until `bazel run //:stop` removes it.

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

## Example runthrough of Vespa commands

```console
# put the embedding in
bash-5.3$ vespa document put id:demo:doc::violin --data '{"fields": {"text": "violin", "embedding": {"values": [0.0, 0.1, 0.0, 0.0, 0.85, 0.85, 0.0, 0.1]}}}'
Success: put id:demo:doc::violin

# query it back out, see that it's encrypted
bash-5.3$ vespa document get id:demo:doc::violin
{
    "pathId": "/document/v1/demo/doc/docid/violin",
    "id": "id:demo:doc::violin",
    "fields": {
        "text": "violin",
        "embedding": {
            "type": "tensor<float>(x[8])",
            "values": [
                0.11757437884807587,
                -0.03741198033094406,
                -0.017604544758796692,
                0.03553548455238342,
                0.8509227633476257,
                -0.11918745189905167,
                0.038667697459459305,
                0.7788750529289246
            ]
        },
        "embedding_metadata": "AAAAAYEACgxHrI5T10wB7x50nM4SIF6bGE7qpvcOxwlqzvD0nTeOU4zqNvO48t1Qd8ilFELC"
    }
}

# query the instrument category w/ an embedding, bypassing the Alloy plugin. Does not include the violin
bash-5.3$ vespa query 'yql=select text from doc where {targetHits: 3}nearestNeighbor(embedding, q)' 'input.query(q)=[0.05, 0.05, 0.05, 0.05, 0.85, 0.85, 0.05, 0.05]' ranking=closest hits=3 searchChain=vespa
{
    "root": {
        "children": [
            {
                "fields": {
                    "matchfeatures": {
                        "distance(field,embedding)": 1.0346295438277027
                    },
                    "text": "truck"
                },
                "id": "index:docs/0/a9cb430bc907b31d690221d3",
                "relevance": 0.49148996338602385,
                "source": "docs"
            },
            {
                "fields": {
                    "matchfeatures": {
                        "distance(field,embedding)": 1.125380981361623
                    },
                    "text": "piano"
                },
                "id": "index:docs/0/d113f1c3cd45be8b804bd7c6",
                "relevance": 0.4705038808427424,
                "source": "docs"
            },
            {
                "fields": {
                    "matchfeatures": {
                        "distance(field,embedding)": 1.1644318269959255
                    },
                    "text": "guitar"
                },
                "id": "index:docs/0/4c39e90df9e1b66077b375df",
                "relevance": 0.4620150136065628,
                "source": "docs"
            }
        ],
        "coverage": {
            "coverage": 100,
            "documents": 7,
            "full": true,
            "nodes": 1,
            "results": 1,
            "resultsFull": 1
        },
        "fields": {
            "totalCount": 3
        },
        "id": "toplevel",
        "relevance": 1
    }
}

# query using the plugin, violin now displaces "truck" as one of the closest matches.
bash-5.3$ vespa query 'yql=select text from doc where {targetHits: 3}nearestNeighbor(embedding, q)' 'input.query(q)=[0.05, 0.05, 0.05, 0.05, 0.85, 0.85, 0.05, 0.05]' ranking=closest hits=3
{
    "root": {
        "children": [
            {
                "fields": {
                    "matchfeatures": {
                        "distance(field,embedding)": 0.23572567531906885
                    },
                    "text": "guitar"
                },
                "id": "index:docs/0/4c39e90df9e1b66077b375df",
                "relevance": 0.8092410961209464,
                "source": "docs"
            },
            {
                "fields": {
                    "matchfeatures": {
                        "distance(field,embedding)": 0.3595242604981712
                    },
                    "text": "violin"
                },
                "id": "index:docs/0/baed9eeee2ab9db4b84bafeb",
                "relevance": 0.7355514197544143,
                "source": "docs"
            },
            {
                "fields": {
                    "matchfeatures": {
                        "distance(field,embedding)": 0.42668048149271787
                    },
                    "text": "piano"
                },
                "id": "index:docs/0/d113f1c3cd45be8b804bd7c6",
                "relevance": 0.7009277921526708,
                "source": "docs"
            }
        ],
        "coverage": {
            "coverage": 100,
            "documents": 7,
            "full": true,
            "nodes": 1,
            "results": 1,
            "resultsFull": 1
        },
        "fields": {
            "totalCount": 3
        },
        "id": "toplevel",
        "relevance": 1
    }
}
```
