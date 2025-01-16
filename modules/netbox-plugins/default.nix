{ callPackage }:
{
  netbox_qrcode = callPackage ./netbox-qrcode.nix { };
  netbox_floorplan = callPackage ./netbox-floorplan.nix { };
  netbox_topology_views = callPackage ./netbox-topology-views.nix { };
  netbox_proxbox = callPackage ./netbox-proxbox.nix { };
  netbox_interface_synchronization = callPackage ./netbox-interface-synchronization.nix { };
  netbox_dns = callPackage ./netbox-dns.nix { };
}
