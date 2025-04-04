{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-sh = {
      url = "github:Defelo/deploy-sh";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secshell.url = "github:secshellnet/nixos";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ifstate = {
      url = "git+https://codeberg.org/m4rc3l/ifstate.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dns = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      sops-nix,
      deploy-sh,
      secshell,
      ifstate,
      ...
    }@inputs:
    let
      mkPkgs =
        {
          system,
          repo ? nixpkgs,
        }:
        import repo {
          inherit system;
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (repo.lib.getName pkg) [
              # Note: If your system requires non free packages, you need to
              #       allow the usage of them here. Examples for non free
              #       packages are mongodb or elasticsearch. If you are using
              #       unfree packages the installation will fail and provide
              #       instructions on what to add in this section.
            ];
          config.permittedInsecurePackages = [
            "olm-3.2.16" # required for matrix bridges, see https://github.com/NixOS/nixpkgs/pull/334638
          ];
          overlays = [
            ifstate.overlays.default
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
    in
    {
      nixosConfigurations =
        let
          hosts =
            let
              listHosts =
                dir:
                let
                  dirContent = builtins.readDir dir;
                  isHost = dirContent."configuration.nix" or null == "regular";
                in
                if isHost then
                  [ dir ]
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
              system =
                if lib.pathExists /${host}/system.txt then
                  lib.removeSuffix "\n" (builtins.readFile /${host}/system.txt)
                else
                  "x86_64-linux";
              pkgs = mkPkgs { inherit system; };
              specialArgs =
                inputs
                // (lib.mapAttrs' (name: value: {
                  name = lib.removePrefix "nix" name;
                  value = mkPkgs {
                    inherit system;
                    repo = value;
                  };
                }) (lib.filterAttrs (name: _: lib.hasPrefix "nixpkgs-" name) inputs))
                // {
                  docker-images = fromTOML (builtins.readFile ./docker-images.toml);
                  libS = secshell.lib {
                    inherit
                      self
                      pkgs
                      lib
                      ;
                  };
                };
              modules = [
                deploy-sh.nixosModules.default
                sops-nix.nixosModules.default
                secshell.nixosModules.default
                ifstate.nixosModules.default
                /${host}/configuration.nix
                ./modules/default.nix
                {
                  networking.hostName = builtins.head (lib.splitString "." (makeFqdn host));
                  networking.domain = builtins.concatStringsSep "." (
                    builtins.tail (lib.splitString "." (makeFqdn host))
                  );
                  deploy-sh.targetHost = "root@${makeFqdn host}";
                  sops.defaultSopsFile = /${host}/secrets.yaml;
                }
              ];
            };
          }) hosts
        );

      deploy-sh.hosts = lib.filterAttrs (_: host: host.config ? "deploy-sh") self.nixosConfigurations;

      devShells = eachDefaultSystem (system: {
        default = import ./shell.nix { inherit inputs system; };
      });

      checks = eachDefaultSystem (system: import ./checks { inherit inputs system; });
    };
}
