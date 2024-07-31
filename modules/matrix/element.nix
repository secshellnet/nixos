{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.secshell.matrix.element = {
    enable = lib.mkEnableOption "element";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "element.${toString config.networking.fqdn}";
    };
  };
  config = lib.mkIf config.secshell.matrix.element.enable {
    services.nginx = {
      enable = true;
      virtualHosts.${toString config.secshell.matrix.element.domain} = {
        forceSSL = true;
        useACMEHost = config.secshell.matrix.element.domain;
        root = pkgs.element-web.override {
          conf = {
            default_server_config = {
              "m.homeserver" = {
                base_url = "https://${toString config.secshell.matrix.domain}";
                server_name = toString config.secshell.matrix.homeserver;
              };
              "m.identity_server" = {
                base_url = "https://vector.im";
              };
            };
            disable_custom_urls = true;
            showLabsSettings = true;
            default_theme = "dark";
            room_directory.servers = [ config.secshell.matrix.homeserver ];
            setting_defaults = {
              "UIFeature.registration" = false;
              "UIFeature.passwordReset" = false;
            };
          };
        };
      };
    };

    security.acme.certs."${toString config.secshell.matrix.element.domain}" = { };
  };
}
