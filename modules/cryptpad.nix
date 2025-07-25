{
  config,
  lib,
  ...
}:
{
  options.secshell.cryptpad = {
    enable = lib.mkEnableOption "cryptpad";
    # for more information regarding domain setup see
    # https://docs.cryptpad.org/en/dev_guide/general.html
    domain = lib.mkOption {
      type = lib.types.str;
      default = "cryptpad.${toString config.networking.fqdn}";
      defaultText = "cryptpad.\${toString config.networking.fqdn}";
      description = ''
        The primary (unsafe) domain where CryptPad's sensitive data layer is loaded.
        This URL handles encrypted user content in memory (drive, contacts, teams),
        and must be served over HTTPS in production.

        Security note: Vulnerabilities in the UI won't expose this layer's data
        due to sandboxing, but this domain still requires strict security headers.
      '';
    };
    sandboxDomain = lib.mkOption {
      type = lib.types.str;
      default = "sandbox.cryptpad.${toString config.networking.fqdn}";
      defaultText = "sandbox.cryptpad.\${toString config.networking.fqdn}";
      description = ''
        The isolated sandbox domain (loaded in an iframe) that renders the UI.
        This domain never receives sensitive user data - it only displays document content
        passed through the sandboxing system.

        Operational note: Must share the same top-level domain as
        the unsafe origin for cookie/tracking purposes.
      '';
    };
    internal_port = lib.mkOption {
      type = lib.types.port;
      description = ''
        The local port the service listens on.
      '';
    };
    internal_ws_port = lib.mkOption {
      type = lib.types.port;
      description = ''
        The local port the websocket listener of the service listens on.
      '';
    };
  };

  config = lib.mkIf config.secshell.cryptpad.enable {
    services = {
      cryptpad = {
        enable = true;
        configureNginx = true;
        settings = {
          httpAddress = "127.0.0.1";
          httpPort = config.secshell.cryptpad.internal_port;
          websocketPort = config.secshell.cryptpad.internal_ws_port;
          httpUnsafeOrigin = "https://${config.secshell.cryptpad.domain}";
          httpSafeOrigin = "https://${config.secshell.cryptpad.sandboxDomain}";
        };
      };
      # use ACME DNS-01 challenge
      nginx.virtualHosts."${config.secshell.cryptpad.domain}" = {
        enableACME = false;
        useACMEHost = config.secshell.cryptpad.domain;
      };
    };
    security.acme.certs."${config.secshell.cryptpad.domain}" = {
      extraDomainNames = [ config.secshell.cryptpad.sandboxDomain ];
    };
  };
}
