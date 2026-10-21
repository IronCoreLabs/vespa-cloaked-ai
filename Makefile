VESPA_SRC     ?= ../vespa
VESPA_REF     ?= HEAD
VESPA_VERSION ?= $(shell scripts/vespa-version.sh $(VESPA_SRC) $(VESPA_REF))
IMAGE         ?= vespa-el10:$(VESPA_VERSION)
ALLOY_VERSION ?= 0.16.1

RPM_DIR := $(CURDIR)/out/rpms

.PHONY: rpms image plugin demo clean

rpms:
	@test -n "$(VESPA_VERSION)"
	mkdir -p $(RPM_DIR)
	docker run --rm \
	  -e VESPA_REF=$(VESPA_REF) -e VESPA_VERSION=$(VESPA_VERSION) \
	  -v $(abspath $(VESPA_SRC)):/vespa-src:ro \
	  -v $(CURDIR)/build/build-rpms.sh:/build-rpms.sh:ro \
	  -v $(RPM_DIR):/out \
	  -v vespa-el10-m2:/root/.m2 \
	  -v vespa-el10-go:/root/go \
	  docker.io/almalinux:10 /build-rpms.sh

image:
	@test -n "$(VESPA_VERSION)"
	docker build --build-arg VESPA_VERSION=$(VESPA_VERSION) \
	  --build-context rpms=$(RPM_DIR) \
	  -t $(IMAGE) -f build/Dockerfile build

plugin:
	@test -n "$(VESPA_VERSION)"
	docker run --rm \
	  -v $(CURDIR)/plugin:/plugin -w /plugin \
	  -v vespa-cloaked-ai-plugin-m2:/root/.m2 \
	  docker.io/maven:3-eclipse-temurin-25 \
	  mvn --batch-mode -Dvespa.version=$(VESPA_VERSION) -Dalloy.version=$(ALLOY_VERSION) package
	mkdir -p app/components
	cp plugin/target/cloaked-ai-vespa-plugin-deploy.jar app/components/

demo:
	@test -n "$(VESPA_VERSION)"
	IMAGE=$(IMAGE) demo/run-demo.sh

clean:
	rm -rf out plugin/target app/components
