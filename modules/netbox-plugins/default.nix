{ callPackage }:
{
  netbox-proxbox = callPackage ./netbox-proxbox.nix { };
  netbox-contract = callPackage ./netbox-contract.nix { };
}
