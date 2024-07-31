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
  };
  config = lib.mkIf config.secshell.bind.enable {
    services.bind = {
      enable = true;
      forwarders = [ ];
      zones = config.secshell.bind.zones;
      extraOptions = ''
        recursion no;

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
