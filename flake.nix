{
  outputs =
    { ... }:
    {
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
            ./modules/peering-manager.nix
            ./modules/radicale.nix
            ./modules/simple-upload.nix
            ./modules/unifi.nix
            ./modules/vaultwarden.nix
            ./modules/woodpecker.nix
            ./modules/zammad.nix

            # Other
            ./modules/containers.nix
            ./modules/filebeat.nix
            ./modules/firewall.nix
            ./modules/hardening.nix
            ./modules/nginx.nix
            ./modules/acme.nix
            ./modules/postgres.nix
            ./modules/user.nix
            ./modules/bind.nix
          ];
        };
      };
      lib = args: import ./lib args;
    };
}
