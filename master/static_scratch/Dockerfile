FROM fedora:44 AS build

LABEL maintainer.0="Will Clark (@willcl-ark)"

RUN dnf update -y \
    && dnf install --setopt=install_weak_deps=False -y \
    cmake \
    file \
    gcc \
    gcc-c++ \
    git \
    glibc-static \
    make \
    libstdc++-static \
    patch \
    pkg-config \
    which

ARG COMMIT=master

WORKDIR /src

RUN git clone -b "$COMMIT" --single-branch --depth 1 "https://github.com/bitcoin/bitcoin.git" && \
    cd bitcoin && \
    git fetch origin "$COMMIT" && \
    git checkout "$COMMIT" && \
    git clean -fdx

WORKDIR /src/bitcoin

RUN make -C depends -j$(nproc) NO_IPC=1 NO_QT=1 NO_USDT=1 NO_WALLET=1 NO_ZMQ=1

RUN LDFLAGS="-static-libstdc++ -static-libgcc -Wl,-O2" \
    cmake -B build \
    --toolchain=depends/$(./depends/config.guess)/toolchain.cmake \
    -DAPPEND_LDFLAGS="-static" \
    -DBUILD_BENCH=OFF \
    -DBUILD_BITCOIN_BIN=OFF \
    -DBUILD_CLI=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_UTIL=OFF \
    -DENABLE_EXTERNAL_SIGNER=OFF \
    -DREDUCE_EXPORTS=ON \
  && cmake --build build -j$(nproc) --target bitcoind \
  && strip build/bin/bitcoind \
  && file build/bin/bitcoind

FROM scratch

COPY --from=build /src/bitcoin/build/bin/bitcoind /bitcoind

EXPOSE 8332 8333 18332 18333 18443 18444 38332 38333

ENTRYPOINT ["/bitcoind"]
