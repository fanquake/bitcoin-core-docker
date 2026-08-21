{
  lib,
  pkgs,
  source,
}:

let
  ccacheStats = "${pkgs.ccache}/bin/ccache";

  stdenv = pkgs.ccacheStdenv.override {
    stdenv = pkgs.stdenv;
    extraConfig = ''
      if [ -d /ccache ] && [ -w /ccache ]; then
        unset CCACHE_DISABLE
        export CCACHE_DIR=/ccache
        export CCACHE_COMPRESS=1
        export CCACHE_COMPILERCHECK=content
        export CCACHE_MAXSIZE=2G
        export CCACHE_SLOPPINESS=random_seed
      else
        export CCACHE_DISABLE=1
      fi
    '';
  };

  zeromq = pkgs.zeromq.override {
    enableCurve = false;
    enableDrafts = false;
    libsodium = null;
  };

  runtimeRpath = lib.makeLibraryPath (
    [
      pkgs.capnproto-runtime
      zeromq
      pkgs.sqlite
      pkgs.stdenv.cc.cc
    ]
    ++ lib.optionals (pkgs ? glibc) [ pkgs.glibc ]
  );

  nativeBuildInputs = with pkgs; [
    cmake
    ninja
    patchelf
    pkg-config
    python3
  ];

  buildInputs = [
    pkgs.boost
    pkgs.capnproto
    pkgs.sqlite
    zeromq
  ];
in
stdenv.mkDerivation {
  pname = "bitcoin-core";
  version = "31.99.0";
  src = source;

  inherit nativeBuildInputs buildInputs;

  cmakeFlags = [
    "-DBUILD_BITCOIN_BIN=ON"
    "-DBUILD_CLI=ON"
    "-DBUILD_DAEMON=ON"
    "-DBUILD_GUI=OFF"
    "-DBUILD_TESTS=OFF"
    "-DBUILD_TX=ON"
    "-DBUILD_UTIL=ON"
    "-DBUILD_WALLET_TOOL=ON"
    "-DENABLE_EXTERNAL_SIGNER=OFF"
    "-DENABLE_IPC=ON"
    "-DENABLE_WALLET=ON"
    "-DINSTALL_MAN=OFF"
    "-DWITH_CCACHE=OFF"
    "-DWITH_USDT=OFF"
    "-DWITH_ZMQ=ON"
  ];

  preBuild = ''
    if [ -d /ccache ] && [ -w /ccache ]; then
      CCACHE_DIR=/ccache ${ccacheStats} --zero-stats
    fi
  '';

  postBuild = ''
    if [ -d /ccache ] && [ -w /ccache ]; then
      CCACHE_DIR=/ccache ${ccacheStats} --show-stats
    fi
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/bitcoin $out/bin/bitcoin
    install -Dm755 bin/bitcoind $out/bin/bitcoind
    install -Dm755 bin/bitcoin-cli $out/bin/bitcoin-cli
    install -Dm755 bin/bitcoin-tx $out/bin/bitcoin-tx
    install -Dm755 bin/bitcoin-util $out/bin/bitcoin-util
    install -Dm755 bin/bitcoin-wallet $out/bin/bitcoin-wallet
    install -Dm755 bin/bitcoin-node $out/libexec/bitcoin-node
    runHook postInstall
  '';

  postFixup = ''
    for binary in $out/bin/bitcoin-cli $out/libexec/bitcoin-node; do
      patchelf --set-rpath "${runtimeRpath}" "$binary"
      patchelf --shrink-rpath "$binary"
    done
  '';

  passthru = {
    inherit zeromq;
    buildPlatform = stdenv.buildPlatform.system;
    hostPlatform = stdenv.hostPlatform.system;
  };
}
