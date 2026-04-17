FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder
LABEL maintainer="nekohasekai <contact-git@sekai.icu>"
COPY . /go/src/github.com/sagernet/sing-box
WORKDIR /go/src/github.com/sagernet/sing-box
ARG TARGETOS TARGETARCH
ARG OBFS_NAME
ARG GOPROXY=""
ENV GOPROXY ${GOPROXY}

ENV CGO_ENABLED=1
ENV GOOS=$TARGETOS
ENV GOARCH=$TARGETARCH

RUN set -ex \
    && apk add git build-base curl clang lld musl-dev \
    && export COMMIT=$(git rev-parse --short HEAD) \
    && export VERSION=$(go run ./cmd/internal/read_tag) \
    && export CC=clang \
    && export CXX=clang++ \
    && export CGO_CFLAGS="-I/usr/include" \
    && export CGO_LDFLAGS="-L/usr/lib -fuse-ld=lld -static" \
    && go build -v -trimpath -tags \
        "with_gvisor,with_wireguard,with_naive_outbound,with_musl,with_quic,badlinkname,tfogo_checklinkname0" \
        -o /go/bin/${OBFS_NAME} \
        -ldflags "-linkmode=external -extld=clang -extldflags='-static' -X \"github.com/sagernet/sing-box/constant.Version=$VERSION\" -X 'internal/godebug.defaultGODEBUG=multipathtcp=0' -s -w -buildid= -checklinkname=0" \
        ./cmd/sing-box

FROM --platform=$TARGETPLATFORM alpine AS dist
LABEL maintainer="nekohasekai <contact-git@sekai.icu>"
ARG OBFS_NAME
RUN set -ex \
    && apk add --no-cache --upgrade bash tzdata ca-certificates nftables
COPY --from=builder /go/bin/${OBFS_NAME} /usr/bin/${OBFS_NAME}
RUN ln -s ${OBFS_NAME} /usr/bin/bin
ENTRYPOINT ["bin"]
