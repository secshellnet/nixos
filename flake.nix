{
  outputs = { ... }: {
    nixosModules = {
      hedgedoc = import ./modules/hedgedoc.nix;
      simple-upload = import ./modules/simple-upload.nix;
      nginx = import ./modules/nginx.nix;
      postgres = import ./modules/postgres.nix;
      containers = import ./modules/containers.nix;
      gitea = import ./modules/gitea.nix;
      vaultwarden = import ./modules/vaultwarden.nix;
      netbox = import ./modules/netbox.nix;
      keycloak = import ./modules/keycloak.nix;
      paperless = import ./modules/paperless.nix;
    };
  };
}
