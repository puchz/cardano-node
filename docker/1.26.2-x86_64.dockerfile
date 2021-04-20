FROM ubuntu:20.04 as builder

# https://stackoverflow.com/questions/22466255/is-it-possible-to-answer-dialog-questions-when-installing-under-docker
ARG DEBIAN_FRONTEND=noninteractive

ARG CARDANO_VERSION=1.26.2
ARG GHC_VERSION="8.10.2"
ARG CABAL_VERSION="3.4.0.0"
ARG OS_ARCH="x86_64"

# Packages and tools needed
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y automake build-essential pkg-config libffi-dev libgmp-dev \
    libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ git jq wget libncursesw5 libtool autoconf llvm libnuma-dev curl

# Install GHC
# The Glasgow Haskell Compiler
WORKDIR /build/ghc
RUN curl https://downloads.haskell.org/ghc/${GHC_VERSION}/ghc-${GHC_VERSION}-${OS_ARCH}-deb10-linux.tar.xz | \
    tar -Jx -C /build/ghc
RUN cd ghc-${GHC_VERSION} && ./configure && make install

# Install Cabal
# The Haskell Common Architecture for Building Applications and Libraries
WORKDIR /build/cabal
RUN curl https://downloads.haskell.org/~cabal/cabal-install-${CABAL_VERSION}/cabal-install-${CABAL_VERSION}-${OS_ARCH}-ubuntu-16.04.tar.xz | \
    tar -Jx -C /usr/bin/
RUN cabal update
RUN cabal --version

# Install Libsodium en /usr/local/lib
WORKDIR /build/libsodium
RUN git clone https://github.com/input-output-hk/libsodium
WORKDIR /build/libsodium/libsodium
RUN git checkout 66f017f1
RUN ./autogen.sh && ./configure && make && make install

# Set Environment variables
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

WORKDIR /build/cardano-node
RUN git clone https://github.com/input-output-hk/cardano-node.git
WORKDIR /build/cardano-node/cardano-node
RUN git fetch --all --recurse-submodules --tags
RUN git checkout tags/${CARDANO_VERSION}

RUN cabal configure --with-compiler=ghc-${GHC_VERSION}
RUN echo "package cardano-crypto-praos" >>  cabal.project.local
RUN echo " flags: -external-libsodium-vrf" >>  cabal.project.local
RUN cabal build all

FROM ubuntu:20.04
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends netbase jq libnuma-dev openssl wget \
  && rm -rf /var/lib/apt/lists/*

## Libsodium refs
COPY --from=builder /usr/local/lib /usr/local/lib

## Environment variables
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

RUN rm -fr /usr/local/lib/ghc-8.10.2

ARG NODE_BUILD_NUM
WORKDIR /etc/config
## mainnet
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/mainnet-config.json
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/mainnet-byron-genesis.json
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/mainnet-shelley-genesis.json
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/mainnet-topology.json
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/mainnet-db-sync-config.json
## testnet
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/testnet-config.json
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/testnet-byron-genesis.json
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/testnet-shelley-genesis.json
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/testnet-topology.json
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/testnet-db-sync-config.json
## restconfig
RUN wget --no-check-certificate https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/rest-config.json

COPY --from=builder /build/cardano-node/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-node-1.26.2/x/cardano-node/build/cardano-node/cardano-node /usr/local/bin/
COPY --from=builder /build/cardano-node/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-cli-1.26.2/x/cardano-cli/build/cardano-cli/cardano-cli /usr/local/bin/

## Attempt to check on the prometheus metrics port if the node is up and running
HEALTHCHECK --interval=10s --timeout=60s --start-period=300s --retries=3 CMD curl -f http://localhost:12798/metrics || exit 1

ENTRYPOINT ["bash", "-c"]
