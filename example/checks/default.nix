{ inputs, system }:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;

  pkgs = import nixpkgs { inherit system; };

  tests = builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.));
in
builtins.listToAttrs (
  map (test: {
    name = test;
    value = pkgs.testers.runNixOSTest (import ./${test} { inherit lib pkgs; });
  }) tests
)
