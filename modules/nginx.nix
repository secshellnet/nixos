{
  lib,
  config,
  pkgs,
  ...
}:
let
  # generate multiline string of modsecurity rules with automatic indexing
  genModsecRules =
    rules:
    builtins.concatStringsSep "\n" (
      lib.lists.imap0 (
        i: v: builtins.replaceStrings [ "id:AUTO" ] [ "id:${toString (10000 + i)}" ] v
      ) rules
    );
in
{
  options.secshell.nginx = {
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

      preRules = lib.mkOption {
        type = with lib.types; listOf lines;
        default = [ ];
      };
      pre = lib.mkOption {
        type = lib.types.lines;
        default = genModsecRules config.secshell.nginx.modsecurity.preRules;
      };
      preFile = lib.mkOption {
        type = lib.types.path;
        default = pkgs.writeText "modsecurity_pre.conf" config.secshell.nginx.modsecurity.pre;
      };

      postRules = lib.mkOption {
        type = with lib.types; listOf lines;
        default = [ ];
      };
      post = lib.mkOption {
        type = lib.types.lines;
        default = genModsecRules config.secshell.nginx.modsecurity.postRules;
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
          rev = "v4.16.0";
          hash = "sha256-RYCv5ujnzLua26OtGBi1r5+8qZKddmKb/8No4cfIhTE=";
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
  };
}
