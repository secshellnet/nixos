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
    nixosConfigurations = let
      hosts = let
        listHosts = dir: let
          dirContent = builtins.readDir dir;
          isHost = dirContent."configuration.nix" or null == "regular";
        in
          if isHost
          then [dir]
          else
            lib.pipe dirContent [
              (lib.filterAttrs (_: type: type == "directory"))
              builtins.attrNames
              (map (x: listHosts /${dir}/${x}))
              builtins.concatLists
            ];
      in
        listHosts ./hosts;

      makeFqdn = lib.flip lib.pipe [
        (lib.path.removePrefix ./hosts)
        lib.path.subpath.components
        lib.reverseList
        (builtins.concatStringsSep ".")
      ];
    in
      builtins.listToAttrs (
        map (host: {
          name = makeFqdn host;
          value = lib.nixosSystem rec {
            system = if lib.pathExists /${host}/system.txt
                     then lib.removeSuffix "\n" (builtins.readFile /${host}/system.txt)
                     else "x86_64-linux";
            pkgs = mkPkgs { inherit system; };
            specialArgs =
              inputs
              // (lib.mapAttrs' (name: value: {
                name = lib.removePrefix "nix" name;
                value = mkPkgs { inherit system; repo = value; };
              }) (lib.filterAttrs (name: _: lib.hasPrefix "nixpkgs-" name) inputs))
              // {
                docker-images = fromTOML (builtins.readFile ./docker-images.toml);
              };
            modules = [
              deploy-sh.nixosModules.default
              sops-nix.nixosModules.default
              secshell.nixosModules.default
              /${host}/configuration.nix
              ./modules/default.nix
              {
                networking.hostName = builtins.head (lib.splitString "." (makeFqdn host));
                networking.domain = builtins.concatStringsSep "." (builtins.tail (lib.splitString "." (makeFqdn host)));
                deploy-sh.targetHost = "root@${makeFqdn host}";
                sops.defaultSopsFile = /${host}/secrets.yaml;
              }
            ];
          };
        })
        hosts
      );

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
