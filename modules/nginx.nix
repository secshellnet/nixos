{ lib
, config
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
  };
  config = lib.mkIf config.services.nginx.enable {
    sops.secrets."cloudflareToken".owner = "root";

    services.nginx = {
      enableReload = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedZstdSettings = true;
      recommendedGzipSettings = true;
      recommendedBrotliSettings = true;
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
        credentialsFile = config.sops.secrets."cloudflareToken".path;
      };
    };
  };
}
