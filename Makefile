UPSTREAM  := https://github.com/SagerNet/sing-box.git
REGISTRY  := ghcr.io
IMAGE     := $(REGISTRY)/rpph4kqocmjkm2ve/sing-box
VERSION   ?=
PLATFORM  ?= linux/amd64
BUILDDIR  := .build/src

TAG = $(IMAGE):$(patsubst v%,%,$(VERSION))

.PHONY: build push clean check-upstream

build: clean
ifndef VERSION
	$(error VERSION is required — make build VERSION=v1.13.2)
endif
	git clone --branch $(VERSION) --depth 1 $(UPSTREAM) $(BUILDDIR)
	cp Dockerfile $(BUILDDIR)/Dockerfile
	podman build --platform $(PLATFORM) -t $(TAG) $(BUILDDIR)
	podman tag $(TAG) $(IMAGE):latest
	@printf '\n:: Built %s\n' "$(TAG)"

push:
ifndef VERSION
	$(error VERSION is required — make push VERSION=v1.13.2)
endif
	podman push $(TAG)
	podman push $(IMAGE):latest
	@printf ':: Pushed %s\n' "$(TAG)"

clean:
	rm -rf .build

check-upstream:
	@git ls-remote --tags --sort=-v:refname $(UPSTREAM) 'v*' \
		| head -5 \
		| awk '{print $$2}' \
		| sed 's|refs/tags/||'
