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
    renewalNetNs = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
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

    # map over acme certificates and bind services to correct network namespace
    systemd.services = lib.mkIf (config.secshell.acme.renewalNetNs != null) (
      builtins.listToAttrs (
        map (service: {
          name = service;
          value.serviceConfig.NetworkNamespacePath = "/var/run/netns/${config.secshell.acme.renewalNetNs}";
        }) ((map (domain: "acme-${domain}") (lib.attrNames config.security.acme.certs)))
      )
    );
  };
}
