{ callPackage }: {
  netbox_qrcode = callPackage ./netbox-qrcode.nix {};
  netbox_bgp = callPackage ./netbox-bgp.nix {};
  netbox_documents = callPackage ./netbox-documents.nix {};
  netbox_floorplan = callPackage ./netbox-floorplan.nix {};
  netbox_topology_views = callPackage ./netbox-topology-views.nix {};
  drf_extra_fields = callPackage ./drf-extra-fields.nix {};
}
