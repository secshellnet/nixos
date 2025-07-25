{
  lib,
  config,
  ...
}:
let
  mkDisableOption =
    name:
    lib.mkEnableOption name
    // {
      default = true;
      example = false;
    };
in
{
  options.secshell.hardening = mkDisableOption "hardening";

  imports = [
    ./kernel.nix
    ./kernel-modules.nix
    ./kernel-sysctl.nix
    ./memory.nix
    ./nix.nix
    ./ssh.nix
    ./proc.nix
    ./pwquality.nix
  ];

  config = lib.mkIf config.secshell.hardening {
    security = {
      sudo = {
        execWheelOnly = true;
        extraConfig = ''
          Defaults logfile="/var/log/sudo.log"
        '';
      };
      apparmor = {
        enable = lib.mkDefault true;
        killUnconfinedConfinables = lib.mkDefault true;
      };
    };

    # weird logrotate issue during config check
    # cannot find name for group ID 30000
    # https://discourse.nixos.org/t/logrotate-config-fails-due-to-missing-group-30000/28501
    services.logrotate.checkConfig = false;
  };
}
