{
  description = "Elyx Preview packaged from the upstream x86_64 AppImage";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    elyx = pkgs.callPackage ./package.nix { };
  in {
    packages.${system} = {
      inherit elyx;
      default = elyx;
    };

    apps.${system} = {
      elyx = {
        type = "app";
        program = "${elyx}/bin/elyx-preview";
        meta.description = "Launch Elyx Preview";
      };
      cli = {
        type = "app";
        program = "${elyx}/bin/elyx";
        meta.description = "Run the Elyx CLI";
      };
      default = self.apps.${system}.elyx;
    };

    overlays.default = final: prev: {
      elyx = final.callPackage ./package.nix { };
    };
  };
}
