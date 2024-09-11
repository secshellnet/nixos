{ config, lib, ... }:
{
  options.secshell.filebeat = {
    enable = lib.mkEnableOption "filebeat";
    graylogDomain = lib.mkOption {
      type = lib.types.str;
    };
  };
  config = lib.mkIf config.secshell.filebeat.enable {
    services.filebeat = {
      enable = true;
      inputs = {
        journald.id = "everything";
        log = lib.mkIf config.secshell.nginx.modsecurity.enable {
          enabled = true;
          paths = [ "/var/log/nginx/modsec.json" ];
        };
      };
      modules = lib.mkIf config.services.nginx.enable {
        nginx = {
          access = {
            enabled = true;
            var.paths = [ "/var/log/nginx/access.log*" ];
          };
          error = {
            enabled = true;
            var.paths = [ "/var/log/nginx/error.log*" ];
          };
        };
      };
      settings.output.elasticsearch.enabled = false;
      settings.output.logstash = {
        enabled = true;
        hosts = [ config.secshell.filebeat.graylogDomain ];
      };
    };
  };
}
