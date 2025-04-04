# Nix Library for Secure Shell Networks

You can import the library for development / debugging purpose like this:
```sh
# nix repl nixpkgs
:lf .
# get a system
system = builtins.head (lib.attrValues nixosConfigurations)
libS = system._module.specialArgs.libS
```