{ lib
, config
, pkgs
, ...
}: {
  options.secshell.nginx = {
    useStagingEnvironment = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    acmeMail = lib.mkOption {
      type = lib.types.str;
      default = "acme@secshell.net";
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
      preFile = lib.mkOption {
        type = lib.types.path;
        default = pkgs.writeText "modsecurity_pre.conf" "";
      };
      postFile = lib.mkOption {
        type = lib.types.path;
        default = pkgs.writeText "modsecurity_post.conf" "";
      };
    };
  };
  config = lib.mkIf config.services.nginx.enable {
    sops = {
      secrets."cloudflareToken" = {};
      templates."credentials".content = ''
        CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflareToken"}
      '';
    };

    services.nginx = let
      modsecurity_crs = pkgs.fetchFromGitHub {
        owner = "coreruleset";
        repo = "coreruleset";
        rev = "v4.0.0";
        sha256 = "TErAhbD77Oa2IauqBnLD+lMk4aI0hWgLb4CcCjqQRdQ=";
      };
      # TODO logging doesn't work
      modsecurity_conf = pkgs.writeText "modsecurity.conf" ''
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
    in {
      enableReload = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedZstdSettings = true;
      recommendedGzipSettings = true;
      recommendedBrotliSettings = true;

      additionalModules = lib.mkIf config.secshell.nginx.modsecurity.enable [ pkgs.nginxModules.modsecurity ];
      appendHttpConfig = lib.mkIf config.secshell.nginx.modsecurity.enable ''
        modsecurity on;
        modsecurity_rules_file ${modsecurity_conf};
      '';
    };
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    users.users.nginx.extraGroups = [ "acme" ];
    security.acme = {
      acceptTerms = true;
      defaults = {
        email = config.secshell.nginx.acmeMail;
        server = lib.mkIf config.secshell.nginx.useStagingEnvironment "https://acme-staging-v02.api.letsencrypt.org/directory";
        keyType = "ec384";
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";  # required to fix subdomain lookups for cloudflare
        credentialsFile = config.sops.templates."credentials".path;
      };
    };
  };
}
