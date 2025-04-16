FROM debian:12-slim

RUN apt-get update  \
    && apt-get -y --no-install-recommends install  \
       sudo curl git ca-certificates build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install latest mise
RUN curl https://mise.run | MISE_VERSION=v... MISE_INSTALL_PATH=/usr/local/bin/mise sh
