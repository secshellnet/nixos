{ callPackage }:
{
  netbox-proxbox = callPackage ./netbox-proxbox.nix { };
  netbox-kea = callPackage ./netbox-kea.nix { };
}
