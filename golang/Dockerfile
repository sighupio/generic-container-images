ARG GOLANG_VERSION=1.24.4

FROM --platform=${BUILDPLATFORM} golang:${GOLANG_VERSION}-alpine

ARG TARGETOS TARGETARCH

ARG ADDLICENSE_VERSION=v1.1.1
ARG DLV_VERSION=v1.24.2
ARG GINGKO_VERSION=v2.23.4
ARG GOFUMPT_VERSION=v0.8.0
ARG GOIMPORTS_VERSION=v0.34.0
ARG GOLANGCILINT_VERSION=v1.62.0
ARG GOMIGRATE_VERSION=v4.18.3
ARG GORELEASER_VERSION=v2.10.2
ARG GOVULNCHECK_VERSION=v1.1.4
ARG JSON_PATCH_VERSION=v5.9.11

ENV CGO_ENABLED=0
ENV GOARCH=${TARGETARCH}
ENV GOOS=${TARGETOS}
ENV GOPRIVATE=github.com/sighupio/*
ENV PATH=/go/bin/${TARGETOS}_${TARGETARCH}:${PATH}

RUN apk update && \
    apk add build-base curl git jq make util-linux yq docker-cli docker-cli-buildx cosign

RUN go install github.com/google/addlicense@${ADDLICENSE_VERSION} && \
    go install github.com/go-delve/delve/cmd/dlv@${DLV_VERSION} && \
    go install github.com/onsi/ginkgo/v2/ginkgo@${GINGKO_VERSION} && \
    go install mvdan.cc/gofumpt@${GOFUMPT_VERSION} && \
    go install golang.org/x/tools/cmd/goimports@${GOIMPORTS_VERSION} && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@${GOLANGCILINT_VERSION} && \
    go install github.com/golang-migrate/migrate/v4/cmd/migrate@${GOMIGRATE_VERSION} && \
    go install github.com/goreleaser/goreleaser/v2@${GORELEASER_VERSION} && \
    go install golang.org/x/vuln/cmd/govulncheck@${GOVULNCHECK_VERSION} && \
    go install github.com/evanphx/json-patch/v5/cmd/json-patch@${JSON_PATCH_VERSION}
