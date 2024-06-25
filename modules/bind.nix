{ config
, pkgs
, lib
, ...
}: {
  options.secshell.bind = {
    enable = lib.mkEnableOption "bind";
    zones = lib.mkOption {
      type = lib.types.attrs;
      default = {};
    };
    versionText = lib.mkOption {
      type = lib.types.str;
      default = "Authorative Name Server";
    };
  };
  config = lib.mkIf config.secshell.bind.enable {
    services.bind = {
      enable = true;
      forwarders = [];
      zones = config.secshell.bind.zones;
      extraOptions = ''
        recursion no;

        # obscure bind9 chaos version queries
        version "${config.secshell.bind.versionText}";

        # track stats on zones
        zone-statistics yes;
      '';
    };
  };
}
