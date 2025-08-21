FROM debian:12-slim

RUN apt-get update  \
    && apt-get -y --no-install-recommends install  \
       sudo curl git ca-certificates build-essential docker.io \
    && rm -rf /var/lib/apt/lists/*

ARG MISE_VERSION
RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh
