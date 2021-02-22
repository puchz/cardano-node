FROM cabal:3.2.0.0 as cabal

FROM ubuntu:20.04 as builder

ENV DEBIAN_FRONTEND=noninteractive
ARG GHC_VERSION="8.10.2"
ARG OS_ARCH="x86_64-deb9"
ARG CARDANO_VERSION="1.24.2"

# Packages and tools needed
RUN apt-get update     && apt-get upgrade -y     && apt-get install -y automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev     zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf

WORKDIR /home/src

# Install GHC - The Glasgow Haskell Compiler en /usr/local/lib/ghc-8.10.2/
RUN wget https://downloads.haskell.org/~ghc//ghc---linux.tar.xz
RUN tar -xf ghc---linux.tar.xz
RUN rm ghc---linux.tar.xz
RUN cd ghc- && ./configure && make install

# Install Libsodium en /usr/local/lib
RUN git clone https://github.com/input-output-hk/libsodium
WORKDIR /home/src/libsodium
RUN git checkout 66f017f1
RUN ./autogen.sh && ./configure && make && make install

ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

# Cabal to PATH
COPY --from=cabal /usr/bin/cabal /usr/bin
RUN cabal update
RUN cabal --version

WORKDIR /home/src
RUN git clone --branch  https://github.com/input-output-hk/cardano-node.git

WORKDIR /home/src/cardano-node
RUN cabal configure --with-compiler=ghc-8.10.2
RUN echo "package cardano-crypto-praos" >>  cabal.project.local
RUN echo "  flags: -external-libsodium-vrf" >>  cabal.project.local
RUN cabal build all

# Install the newly built node and CLI commands
#RUN cabal clean
#RUN cabal update
#RUN cabal install all --bindir /usr/bin

### DEPLOY NODE ################################################################

## Get testnet config files
WORKDIR /home/config/testnet
RUN wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-config.json
RUN wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-shelley-genesis.json
RUN wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-byron-genesis.json
RUN wget https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-topology.json

ARG OS_ARCH=x86_64
ARG GHC_VERSION=8.10.2
ARG CARDANO_VERSION=1.24.2

FROM ubuntu:20.04 as artifacts
RUN apt-get update &&     apt-get upgrade -y &&     apt-get install -y --no-install-recommends netbase jq libnuma-dev &&     rm -rf /var/lib/apt/lists/*

## Libsodium refs
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/bin /usr/bin

## Copy config files
COPY --from=builder /home/config/testnet /etc/config
#COPY --from=builder /home/config/mainnet /etc/config

## Not sure I still need these
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

RUN rm -fr /usr/local/lib/ghc-
COPY --from=builder /home/src/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-node-1.24.2/x/cardano-node/build/cardano-node/cardano-node /usr/local/bin/
COPY --from=builder /home/src/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-cli-1.24.2/x/cardano-cli/build/cardano-cli/cardano-cli /usr/local/bin/

ENTRYPOINT ["bash", "-c"]
