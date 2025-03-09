{
  lib,
  config,
  ...
}:
{
  options.secshell.acme = {
    useStagingEnvironment = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    acmeMail = lib.mkOption {
      type = lib.types.str;
      default = "acme@secshell.net";
    };
  };
  config = lib.mkIf ((builtins.length (builtins.attrNames config.security.acme.certs)) > 0) {
    sops = {
      secrets."cloudflareToken" = { };
      templates."credentials".content = ''
        CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflareToken"}
      '';
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = config.secshell.acme.acmeMail;
        server = lib.mkIf config.secshell.acme.useStagingEnvironment "https://acme-staging-v02.api.letsencrypt.org/directory";
        keyType = "ec384";
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53"; # required to fix subdomain lookups for cloudflare
        credentialsFile = config.sops.templates."credentials".path;
      };
    };
  };
}
