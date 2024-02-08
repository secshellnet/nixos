{
  outputs = { ... }: {
    nixosModules = {
      hedgedoc = import ./modules/hedgedoc.nix;
    };
  };
}
