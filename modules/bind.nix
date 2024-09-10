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
    versionText = lib.mkOption {
      type = lib.types.str;
      default = "Authorative Name Server";
    };
    exporter.enable = mkDisableOption "bind_exporter";
  };
  config = lib.mkIf config.secshell.bind.enable {
    services.bind = {
      enable = true;
      extraOptions =
        let
          # whether bind should be configured as forwarder
          forward = (builtins.length config.services.bind.forwarders) > 0;
        in
        ''
          recursion ${if forward then "yes" else "no"};
          ${lib.optionalString forward ''
            auth-nxdomain no;
            dnssec-validation no;
          ''}

          # obscure bind9 chaos version queries
          version "${config.secshell.bind.versionText}";

          ${lib.optionalString config.secshell.bind.exporter.enable ''
            # track stats on zones
            zone-statistics yes;
          ''}
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
