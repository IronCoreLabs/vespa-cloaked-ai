# Cloaked AI in Vespa

An example of encrypting vector embeddings in [Vespa](https://vespa.ai) with [IronCore Cloaked AI](https://ironcorelabs.com/products/cloaked-ai/), using the standalone vector encryption in [ironcore-alloy](https://github.com/IronCoreLabs/ironcore-alloy) as a Vespa container plugin.

Documents are fed with plaintext vectors and stored encrypted. Queries carry a plaintext vector that is encrypted before it reaches the content nodes, so nearest neighbor search runs entirely on encrypted vectors. The Vespa nodes hold the key; the encrypted index on disk does not reveal the embeddings.

## Why a custom Vespa image

`ironcore-alloy-java` calls its native library through the Java FFM API. Its classes need JDK 22 or newer, and the bundled `libironcore_alloy.so` needs glibc 2.34 or newer. The published Vespa images run AlmaLinux 8 (JDK 17, glibc 2.28), and the AlmaLinux 9 build uses JDK 21 with `--enable-preview` class files that will not run on a newer JDK.

Vespa's RPM spec already supports AlmaLinux 10, where it builds with JDK 25 and glibc 2.39, and Vespa publishes the el10 build dependencies. Vespa does not publish el10 images, so this repo builds one.

## Layout

| Path | Contents |
|---|---|
| `build/build-rpms.sh` | Builds Vespa RPMs from a release tag inside `almalinux:10` |
| `build/Dockerfile` | Vespa runtime image on AlmaLinux 10, adapted from [vespa-engine/docker-image](https://github.com/vespa-engine/docker-image) |
| `plugin/` | The container plugin: `CloakedAi` component, `EncryptVectorsDocumentProcessor`, `EncryptQueryVectorSearcher` |
| `app/` | Vespa application package using the plugin |
| `demo/run-demo.sh` | Starts the image, deploys `app/`, feeds and queries |

## Requirements

Docker 23 or newer (`make image` uses a named build context), roughly 20 GB free in Docker's disk, and a checkout of [vespa-engine/vespa](https://github.com/vespa-engine/vespa) next to this repository:

```sh
git clone https://github.com/vespa-engine/vespa ../vespa
git -C ../vespa checkout v8.763.13
```

Set `VESPA_SRC` to use a checkout elsewhere. The build uses the release tag checked out there; set `VESPA_REF` to build another tag without changing the checkout. Building a ref that is not a `vX.Y.Z` tag requires `VESPA_VERSION`, and that version must be at least the `vespa.version` the plugin is compiled against.

## Running

```sh
make rpms     # Vespa RPMs into out/rpms; a full C++ and Java build, about 40 minutes on 6 arm64 cores
make image    # vespa-el10:<version>
make plugin   # app/components/cloaked-ai-vespa-plugin-deploy.jar
make demo
```

`make rpms` caches Maven and Go downloads in the Docker volumes `vespa-el10-m2` and `vespa-el10-go`; `make plugin` uses `vespa-cloaked-ai-plugin-m2`.

The RPM build skips debug info and `%check`, and works around a spec issue in v8.763.13 that left el10 RPMs requiring abseil sonames no package provides; see the comments in `build/build-rpms.sh`.

The demo feeds six 8-dimensional vectors in three topics, then:

1. Fetches a stored document, showing the encrypted embedding and its `embedding_metadata`.
2. Queries with a plaintext vector near the fruit topic through the default chain, where the searcher encrypts it. Apple and banana rank first.
3. Sends the same query through the built-in `vespa` chain, which skips the searcher, to show that a plaintext query does not match against the encrypted index.
4. Shows that a partial update of `embedding` is rejected.

The container keeps running afterwards on ports 8080 and 19071.

## Using the plugin in your application

Add the jar to your application's `components/` directory, then wire it as in `app/services.xml`:

- One `CloakedAi` component, configured with `cloaked-ai` config (see `plugin/src/main/resources/configdefinitions/cloaked-ai.def`).
- `EncryptVectorsDocumentProcessor` in a document processing chain that inherits `indexing`, referenced from the content cluster.
- `EncryptQueryVectorSearcher` in the search chain your queries use.

The vector field must be a `tensor<float>(x[N])`, and the schema needs a `raw` field for the metadata returned by encryption, which is required to decrypt the vector. Feed whole documents: the document processor rejects partial updates of the vector field. Vespa logs a rejected update at warning level including its field values, so a rejected update's plaintext vector ends up in the Vespa log.

The secret is read from a file holding at least 32 bytes, base64 encoded. The demo generates one and mounts it at `/run/secrets/cloaked-ai-secret`; in production, provision it the way you provision other secrets on Vespa nodes. Every container node that feeds or queries needs the same secret, tenant id and approximation factor.

The plugin copies `libironcore_alloy.so` from the alloy jar to a temporary file at startup and loads it from there. It supports Linux on x86-64 and aarch64.
