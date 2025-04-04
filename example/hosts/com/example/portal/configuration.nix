{
  imports = [
    ./hardware-configuration.nix
    ./disk-configuration.nix
  ];

  secshell = {
    hedgedoc = {
      enable = true;
      internal_port = 8000;
    };
    vaultwarden = {
      enable = true;
      internal_port = 8001;
    };
    users = [
      "alice"
      "bob"
    ];
  };

  system.stateVersion = "24.11";
}
