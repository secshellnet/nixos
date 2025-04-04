{
  self,
  pkgs,
  lib,
}:
rec {
  sys = import ./system.nix { inherit lib self; };
  net = import ./network.nix { inherit lib; };

  /**
    Make a new wireguard interface

    This function creates a new ifstate wireguard interface with the given configuration.
    It uses wireguard/private-key/${interface} and wireguard/psk/${interface} sops secrets
    It configures the firewall to allow the wireguard interface to communicate with the remote endpoint

    Example on how to use this type of function:
     > :lf .
     > pkgs = import inputs.nixpkgs {system = "x86_64-linux"; }
     > mkTest =
       { pkgs }:
       { testContent }:
       pkgs.writeText "test" testContent
     > (mkTest { inherit pkgs; }) { testContent = "test"; }
  */
  mkWg = import ./mkWg.nix {
    inherit lib pkgs;
    libS.net = net;
  };
}
