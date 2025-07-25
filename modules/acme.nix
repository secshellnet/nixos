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
      description = ''
        Whether to use the Let's Encrypt staging environment.
        The staging environment has much higher rate limits, making it ideal for testing,
        but the certificates it issues are not trusted by browsers or other clients.
        Enable this during development or testing to avoid hitting production rate limits.
      '';
    };
    acmeMail = lib.mkOption {
      type = lib.types.str;
      default = "acme@secshell.net";
      description = ''
        The email address to associate with certificate requests to Let's Encrypt.
        This is used for important account notifications, such as expiry warnings,
        and may be required by some ACME servers for registration.
      '';
    };
    renewalNetNs = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        The network namespace in which the ACME systemd services will run.
        If unset, the service runs in the default (global) network namespace.
        Example: Use a dedicated netns with unrestricted outbound traffic for Let's Encrypt.
      '';
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
