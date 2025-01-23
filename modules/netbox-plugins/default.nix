{ callPackage }:
{
  netbox_floorplan = callPackage ./netbox-floorplan.nix { };
  netbox_proxbox = callPackage ./netbox-proxbox.nix { };
}
