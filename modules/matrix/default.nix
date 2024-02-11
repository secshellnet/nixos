{ lib
, ...
}: {
  imports = [
    ./synapse.nix
    ./whatsapp-bridge.nix
    ./telegram-bridge.nix
  ];
}
