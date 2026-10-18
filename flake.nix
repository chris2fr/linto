{
  description = "Linto command-line toolbox";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      nixosModules = {
        default = import ./nix/nixos-module.nix;
        linto = import ./nix/nixos-module.nix;
      };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          package = pkgs.callPackage ./nix/package.nix { };
        in {
          default = package;
          linto = package;
        });
    };
}
