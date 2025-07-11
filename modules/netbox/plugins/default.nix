{ callPackage }:
{
  netbox-proxbox = callPackage ./netbox-proxbox.nix { };
  netbox-contract = callPackage ./netbox-contract.nix { };
  netbox-kea = callPackage ./netbox-kea.nix { };
  netbox-attachments = callPackage ./netbox-attachments.nix { };
  netbox-branching = callPackage ./netbox-branching.nix { };
}
