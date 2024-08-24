{
  config,
  pkgs,
  lib,
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
  options.secshell.bind = {
    enable = lib.mkEnableOption "bind";
    zones = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
    versionText = lib.mkOption {
      type = lib.types.str;
      default = "Authorative Name Server";
    };
    exporter.enable = mkDisableOption "bind_exporter";
    forwarders = lib.mkOption {
      default = [ ];
      type = lib.types.listOf lib.types.str;
      description = ''
        List of servers we should forward requests to.
      '';
    };
  };
  config = lib.mkIf config.secshell.bind.enable {
    services.bind = {
      enable = true;
      forwarders = config.secshell.bind.forwarders;
      zones = config.secshell.bind.zones;
      extraOptions = ''
        recursion ${if (builtins.length config.secshell.bind.forwarders) == 0 then "no" else "yes" };

        ${if (builtins.length config.secshell.bind.forwarders) == 0 then "" else "auth-nxdomain no;" }

        ${if (builtins.length config.secshell.bind.forwarders) == 0 then "" else "dnssec-validation no;" }

        # obscure bind9 chaos version queries
        version "${config.secshell.bind.versionText}";

        # track stats on zones
        zone-statistics yes;
      '';
      extraConfig = lib.mkIf config.secshell.bind.exporter.enable ''
        statistics-channels {
          inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
        };
      '';
    };
    services.prometheus.exporters.bind.enable = config.secshell.bind.exporter.enable;
  };
}
