# Secure Shell Networks: Nix flake for servers

This repository provides nix configurations for servers managed by Secure Shell Networks.

## Example
```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    deploy-sh.url = "github:Defelo/deploy-sh";
    secshell.url = "github:secshellnet/nixos";
  };
  outputs = 
    { self
    , nixpkgs
    , nixpkgs-unstable
    , sops-nix
    , deploy-sh
    , secshell
    , ...
    } @ inputs:
    let
      mkPkgs = { system, repo ? nixpkgs }: import repo {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (repo.lib.getName pkg) [
          # Note: If your system requires non free packages, you need to 
          #       allow the usage of them here. Examples for non free
          #       packages are mongodb or elasticsearch. If you are using
          #       unfree packages the installation will fail and provide
          #       instructions on what to add in this section.
        ];
      };

      inherit (nixpkgs) lib;
      defaultSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachDefaultSystem = lib.genAttrs defaultSystems;
    in {
    nixosConfigurations = {
      # Note: This section of the flake contains your systems.
      "portal.example.com" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        pkgs = mkPkgs { inherit system; };
        specialArgs = inputs // { 
          pkgs-unstable = mkPkgs { inherit system; repo = nixpkgs-unstable; };
          # docker-images = fromTOML (builtins.readFile ./docker-images.toml);
        };
        modules = with self.nixosModules; [
          ./hosts/com/example/portal/configuration.nix
          
          ./modules/default.nix
          
          secshell.nixosModules.default
          deploy-sh.nixosModules.default
          sops-nix.nixosModules.sops
        ];
      };
    };

    deploy-sh.hosts = lib.filterAttrs (_: host: host.config ? "deploy-sh") self.nixosConfigurations;

    devShells = eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          sops
          ssh-to-age
        ] ++ [
          deploy-sh.packages.${system}.default
        ];
      };
    });
  };
}
```

```nix
# hosts/com/example/portal/configuration.nix
{ config
, pkgs
, lib
, ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;
  deploy-sh.targetHost = "root@portal.example.com";

  secshell = {
    hedgedoc = {
      enable = true;
      internal_port = 8000;
    };
    vaultwarden = {
      enable = true;
      internal_port = 8001;
    };
  };

  system.stateVersion = "24.05";
}
```

```nix
# modules/default.nix
{ pkgs
, ...
}: {
  time.timeZone = "Europe/Berlin";
  i18n.extraLocaleSettings.LC_TIME = "en_GB.UTF-8";
  console.keyMap = "de";
  
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  services.openssh = {
    enable = true;
    openFirewall = true;
  };
}
```
