FROM debian:12-slim

RUN apt-get update  \
    && apt-get -y --no-install-recommends install  \
       sudo curl git ca-certificates build-essential docker.io openssh-client \
    && rm -rf /var/lib/apt/lists/*

ARG MISE_VERSION
# Pass MISE_VERSION to the installer so the image tag pins the mise version. Without it the script
# installs the latest release, which makes the tag reflect only the build date.
RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise MISE_VERSION="${MISE_VERSION}" sh
