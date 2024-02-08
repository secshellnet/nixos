{
  outputs = { ... }: {
    nixosModules = {
      hedgedoc = import ./modules/hedgedoc.nix;
      simple-upload = import ./modules/simple-upload.nix;
      nginx = import ./modules/nginx.nix;
      postgres = import ./modules/postgres.nix;
    };
  };
}
