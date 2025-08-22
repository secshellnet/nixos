{ callPackage }:
{
  netbox-proxbox = callPackage ./netbox-proxbox.nix { };
  netbox-kea = callPackage ./netbox-kea.nix { };
  netbox-contextmenus = callPackage ./netbox-contextmenus.nix { };
}
