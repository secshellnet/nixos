{ inputs, system }:
let
  pkgs = import inputs.nixpkgs { inherit system; };
in
pkgs.mkShell {
  packages =
    with pkgs;
    [
      sops
      ssh-to-age
      nixos-anywhere
      nixfmt-rfc-style
      deadnix
    ]
    ++ [ inputs.deploy-sh.packages.${pkgs.stdenv.system}.default ];
}
