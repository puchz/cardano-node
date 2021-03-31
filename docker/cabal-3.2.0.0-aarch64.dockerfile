FROM ubuntu:20.04 as cabal

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev \
    zlib1g-dev make g++ git jq wget libncursesw5 libtool autoconf llvm

# INSTALL GHC
# The Glasgow Haskell Compiler
ARG GHC_VERSION="8.10.2"
ARG OS_ARCH=aarch64
WORKDIR /build/ghc

RUN wget https://downloads.haskell.org/~ghc/${GHC_VERSION}/ghc-${GHC_VERSION}-${OS_ARCH}-deb10-linux.tar.xz
RUN tar -xf ghc-${GHC_VERSION}-${OS_ARCH}-deb10-linux.tar.xz
RUN cd ghc-${GHC_VERSION} && ./configure && make install

# INSTALL CABAL
# The Haskell Common Architecture for Building Applications and Libraries
ARG CABAL_VERSION="3.2.0.0"
WORKDIR /build/cabal
RUN wget -qO- https://github.com/haskell/cabal/archive/Cabal-v${CABAL_VERSION}.tar.gz | tar xzfv - -C . --strip-components 1 \
  && cd cabal-install \
  && ./bootstrap.sh

FROM ubuntu:20.04
COPY --from=cabal /root/.cabal/bin/cabal /usr/bin/
