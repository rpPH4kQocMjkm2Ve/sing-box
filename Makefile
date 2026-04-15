UPSTREAM  := https://github.com/SagerNet/sing-box.git
REGISTRY  := ghcr.io
IMAGE     := $(REGISTRY)/rpph4kqocmjkm2ve/sing-box
VERSION   ?= $(shell cat VERSION)
PLATFORM  ?= linux/amd64
BUILDDIR  := .build/src
TAG       := $(IMAGE):$(patsubst v%,%,$(VERSION))

.PHONY: build push clean check-upstream test

UNIT_TESTS = \
	tests/test_args.sh \
	tests/test_clone.sh \
	tests/test_build.sh

test:
	@for t in $(UNIT_TESTS); do \
		echo ""; \
		echo "━━━ $$t ━━━"; \
		bash "$$t" || exit 1; \
	done

build: clean
	git clone --branch $(VERSION) --depth 1 $(UPSTREAM) $(BUILDDIR)
	cp Dockerfile $(BUILDDIR)/Dockerfile
	podman build --platform $(PLATFORM) -t $(TAG) $(BUILDDIR)
	podman tag $(TAG) $(IMAGE):latest
	@printf '\n:: Built %s\n' "$(TAG)"

push:
	podman push $(TAG)
	podman push $(IMAGE):latest
	@printf ':: Pushed %s\n' "$(TAG)"

clean:
	rm -rf .build

check-upstream:
	@git ls-remote --tags --sort=-v:refname $(UPSTREAM) 'v*' \
		| head -20 \
		| awk '{print $$2}' \
		| sed 's|refs/tags/||'
