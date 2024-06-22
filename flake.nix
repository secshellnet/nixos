{
  outputs = { ... }: {
    nixosModules = {
      default = {
        imports = [
          # Web Applications
          ./modules/gitea.nix
          ./modules/graylog.nix
          ./modules/hedgedoc.nix
          ./modules/keycloak.nix
          ./modules/matrix/default.nix
          ./modules/monitoring/default.nix
          ./modules/netbox.nix
          ./modules/nexus.nix
          ./modules/paperless.nix
          ./modules/simple-upload.nix
          ./modules/unifi.nix
          ./modules/vaultwarden.nix
          ./modules/woodpecker.nix

          # Support Modules
          ./modules/containers.nix
          ./modules/hardening.nix
          ./modules/nginx.nix
          ./modules/postgres.nix
          ./modules/user.nix
        ];
      };
    };
  };
}
