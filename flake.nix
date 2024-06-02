{
  outputs = { ... }: {
    nixosModules = {
      default = {
        imports = [
          ./modules/hedgedoc.nix
          ./modules/simple-upload.nix
          ./modules/nginx.nix
          ./modules/postgres.nix
          ./modules/containers.nix
          ./modules/gitea.nix
          ./modules/woodpecker.nix
          ./modules/vaultwarden.nix
          ./modules/netbox.nix
          ./modules/keycloak.nix
          ./modules/paperless.nix
          ./modules/monitoring/default.nix
          ./modules/matrix/default.nix
          ./modules/unifi.nix
          ./modules/user.nix
          ./modules/nexus.nix
          ./modules/graylog.nix
        ];
      };
    };
  };
}
