FROM cabal:3.2.0.0 as cabal
FROM ubuntu:20.04 as builder

# https://stackoverflow.com/questions/22466255/is-it-possible-to-answer-dialog-questions-when-installing-under-docker
ARG DEBIAN_FRONTEND=noninteractive
ARG GHC_VERSION
ARG OS_ARCH="x86_64-deb9"
ARG CARDANO_VERSION=1.25.1
ARG OS_VERSION

# Packages and tools needed
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y automake build-essential pkg-config libffi-dev libgmp-dev \
    libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ git jq wget libncursesw5 libtool autoconf

WORKDIR /home/src

# Install GHC - The Glasgow Haskell Compiler en /usr/local/lib/ghc-${GHC_VERSION}/
RUN wget https://downloads.haskell.org/~ghc/${GHC_VERSION}/ghc-${GHC_VERSION}-${OS_ARCH}-deb9-${OS_VERSION}.tar.xz
RUN tar -xf ghc-${GHC_VERSION}-${OS_ARCH}-deb9-${OS_VERSION}.tar.xz
RUN rm ghc-${GHC_VERSION}-${OS_ARCH}-deb9-${OS_VERSION}.tar.xz
RUN cd ghc-${GHC_VERSION} && ./configure && make install

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
RUN git clone https://github.com/input-output-hk/cardano-node.git

WORKDIR /home/src/cardano-node
RUN git fetch --all --recurse-submodules --tags
RUN git checkout tags/${CARDANO_VERSION}

RUN cabal configure --with-compiler=ghc-${GHC_VERSION}
RUN echo "package cardano-crypto-praos" >>  cabal.project.local
RUN echo "  flags: -external-libsodium-vrf" >>  cabal.project.local
RUN cabal build cardano-cli cardano-node

# Install the newly built node and CLI commands
#RUN cabal clean
#RUN cabal update
#RUN cabal install all --bindir /usr/bin

### DEPLOY NODE ################################################################

FROM ubuntu:20.04 as artifacts
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends netbase jq libnuma-dev \
  && rm -rf /var/lib/apt/lists/*

## Libsodium refs
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/bin /usr/bin

## Environment variables
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

RUN rm -fr /usr/local/lib/ghc-

# sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-cli") /usr/local/bin/cardano-cli
# sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-node") /usr/local/bin/cardano-node
COPY --from=builder /home/src/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-node-1.25.1/x/cardano-node/build/cardano-node/cardano-node /usr/local/bin/cardano-node
COPY --from=builder /home/src/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-cli-1.25.1/x/cardano-cli/build/cardano-cli/cardano-cli /usr/local/bin/cardano-cli

ENTRYPOINT ["bash", "-c"]
