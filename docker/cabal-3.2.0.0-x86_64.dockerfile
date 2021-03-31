FROM ubuntu:20.04 as cabal

# https://stackoverflow.com/questions/22466255/is-it-possible-to-answer-dialog-questions-when-installing-under-docker
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev \
    zlib1g-dev make g++ git jq wget libncursesw5 libtool autoconf llvm

# INSTALL GHC
# The Glasgow Haskell Compiler
ARG GHC_VERSION="8.10.2"
ARG OS_ARCH
ARG OS_VERSION
WORKDIR /build/ghc
RUN wget https://downloads.haskell.org/ghc/${GHC_VERSION}/ghc-${GHC_VERSION}-${OS_ARCH}-deb9-${OS_VERSION}.tar.xz
RUN tar -xf ghc-${GHC_VERSION}-${OS_ARCH}-deb9-${OS_VERSION}.tar.xz
RUN cd ghc-${GHC_VERSION} && ./configure && make install

# INSTALL CABAL
# The Haskell Common Architecture for Building Applications and Libraries
ARG CABAL_VERSION="3.2.0.0"
WORKDIR /build/cabal
RUN wget https://downloads.haskell.org/~cabal/cabal-install-${CABAL_VERSION}/cabal-install-${CABAL_VERSION}-${OS_ARCH}-unknown-linux.tar.xz
RUN tar -xf cabal-install-${CABAL_VERSION}-${OS_ARCH}-unknown-linux.tar.xz
RUN rm cabal-install-${CABAL_VERSION}-${OS_ARCH}-unknown-linux.tar.xz cabal.sig

FROM ubuntu:20.04
COPY --from=cabal /build/cabal /usr/bin/
