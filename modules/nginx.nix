{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.secshell.nginx = {
    useStagingEnvironment = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        ::: {.warning}
        The option `secshell.nginx.useStagingEnvironment` is deprecated. Use `secshell.acme.useStagingEnvironment` instead.
      '';
    };
    acmeMail = lib.mkOption {
      type = lib.types.str;
      default = "acme@secshell.net";
      description = ''
        ::: {.warning}
        The option `secshell.nginx.acmeMail` is deprecated. Use `secshell.acme.acmeMail` instead.
      '';
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    modsecurity = {
      # TODO After testing has been complete this should be enabled by default at least
      #      with SecRuleEngine DetectionOnly to prevent blocking of legitimate services
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      detectionOnly = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      paranoiaLevel = lib.mkOption {
        type = lib.types.int;
        default = 1;
      };
      pre = lib.mkOption {
        type = lib.types.lines;
        default = "";
      };
      post = lib.mkOption {
        type = lib.types.lines;
        default = "";
      };
      preFile = lib.mkOption {
        type = lib.types.path;
        default = pkgs.writeText "modsecurity_pre.conf" config.secshell.nginx.modsecurity.pre;
      };
      postFile = lib.mkOption {
        type = lib.types.path;
        default = pkgs.writeText "modsecurity_post.conf" config.secshell.nginx.modsecurity.post;
      };
    };
  };
  config = lib.mkIf config.services.nginx.enable {
    services.nginx =
      let
        modsecurity_crs = pkgs.fetchFromGitHub {
          owner = "coreruleset";
          repo = "coreruleset";
          rev = "v4.0.0";
          sha256 = "TErAhbD77Oa2IauqBnLD+lMk4aI0hWgLb4CcCjqQRdQ=";
        };
        modsecurity_conf = pkgs.writeText "modsecurity.conf" ''
          SecAuditEngine RelevantOnly
          SecAuditLog /var/log/nginx/modsec.json
          SecAuditLogFormat JSON
          SecAuditLogParts ABIJDEFHZ

          SecRuleEngine ${if (config.secshell.nginx.modsecurity.detectionOnly) then "DetectionOnly" else "On"}

          SecDefaultAction "phase:1,log,auditlog,pass"
          SecDefaultAction "phase:2,log,auditlog,pass"

          Include ${config.secshell.nginx.modsecurity.preFile}

          SecAction \
              "id:900000,\
              phase:1,\
              pass,\
              t:none,\
              nolog,\
              setvar:tx.blocking_paranoia_level=${toString config.secshell.nginx.modsecurity.paranoiaLevel}"

          SecAction \
              "id:900010,\
              phase:1,\
              pass,\
              t:none,\
              nolog,\
              setvar:tx.enforce_bodyproc_urlencoded=1"

          SecAction \
              "id:900990,\
              phase:1,\
              pass,\
              t:none,\
              nolog,\
              setvar:tx.crs_setup_version=400"

          Include ${modsecurity_crs}/rules/*.conf

          Include ${config.secshell.nginx.modsecurity.postFile}
        '';
      in
      {
        enableReload = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedZstdSettings = true;
        recommendedGzipSettings = true;
        recommendedBrotliSettings = true;

        logError = "/var/log/nginx/error.log";

        additionalModules = lib.mkIf config.secshell.nginx.modsecurity.enable [
          pkgs.nginxModules.modsecurity
        ];
        appendHttpConfig = lib.mkIf config.secshell.nginx.modsecurity.enable ''
          modsecurity on;
          modsecurity_rules_file ${modsecurity_conf};
        '';
      };
    networking.firewall.allowedTCPPorts = lib.mkIf config.secshell.nginx.openFirewall [
      80
      443
    ];

    users.users.nginx.extraGroups = [ "acme" ];

    # fixup renamed options
    secshell.acme = {
      acmeMail = lib.mkDefault config.secshell.nginx.acmeMail;
      useStagingEnvironment = lib.mkDefault config.secshell.nginx.useStagingEnvironment;
    };
  };
}
