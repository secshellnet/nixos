{
  outputs = { ... }: {
    nixosModules = {
      hedgedoc = import ./modules/hedgedoc.nix;
      simple-upload = import ./modules/simple-upload.nix;
    };
  };
}
