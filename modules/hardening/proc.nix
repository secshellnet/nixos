{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.secshell.hardening {
    fileSystems."/proc" = {
      fsType = "proc";
      device = "proc";
      options = [
        "nosuid"
        "nodev"
        "noexec"
        "hidepid=2"
      ];
      neededForBoot = true;
    };
  };
}
