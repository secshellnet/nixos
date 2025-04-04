{
  time.timeZone = "Europe/Berlin";
  i18n.extraLocaleSettings.LC_TIME = "en_GB.UTF-8";
  console.keyMap = "de";

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  secshell = {
    keysDir = ./keys;
    users = [
      "alice"
      "bob"
    ];
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
  };
}
