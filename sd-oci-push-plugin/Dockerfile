ARG ORAS_VERSION
ARG YQ_VERSION
FROM docker.io/mikefarah/yq:${YQ_VERSION} AS yq

# The oras image is Alpine with ca-certificates and /bin/oras.
FROM ghcr.io/oras-project/oras:v${ORAS_VERSION}

RUN apk add --no-cache git curl

COPY --from=yq /usr/bin/yq /usr/bin/yq
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
