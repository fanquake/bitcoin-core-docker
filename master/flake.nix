{
  description = "Bitcoin Core Docker image";

  inputs = {
    bitcoin-src = {
      url = "github:bitcoin/bitcoin/master";
      flake = false;
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      bitcoin-src,
      nixpkgs,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ (import ./nix/overlays.nix) ];
        };

      bitcoinSource = bitcoin-src;

      mkBitcoinCore =
        pkgs:
        import ./nix/bitcoin.nix {
          inherit (pkgs) lib;
          inherit pkgs;
          source = bitcoinSource;
        };

      mkDockerImage =
        {
          pkgs,
          bitcoinCore,
          architecture,
          tag,
        }:
        import ./nix/docker.nix {
          inherit
            pkgs
            bitcoinCore
            architecture
            tag
            ;
        };

      archFor = {
        x86_64-linux = "amd64";
        aarch64-linux = "arm64";
      };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          arch = archFor.${system};
          bitcoin-core = mkBitcoinCore pkgs;
          docker-image = mkDockerImage {
            inherit pkgs;
            bitcoinCore = bitcoin-core;
            architecture = arch;
            tag = "master-${arch}";
          };
        in
        {
          default = docker-image;
          inherit bitcoin-core docker-image;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ (mkBitcoinCore pkgs) ];
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
