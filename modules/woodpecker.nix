{
  config,
  lib,
  ...
}:
let
  cfg = config.secshell.gitea.woodpecker;
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    mkMerge
    mkAfter
    ;
  mkDisableOption =
    name:
    mkEnableOption name
    // {
      default = true;
      example = false;
    };
in
{
  options.secshell.gitea.woodpecker = {
    enable = mkEnableOption "woodpecker";

    enableServer = mkDisableOption "woodpecker-server";
    enableAgent = mkDisableOption "woodpecker-agent";

    domain = mkOption {
      type = types.str;
      default = "woodpecker.${toString config.networking.fqdn}";
      defaultText = "woodpecker.\${toString config.networking.fqdn}";
      description = ''
        The primary domain name for this service.
        Used for virtual host configuration, TLS certificates, and service URLs.
      '';
    };

    internal_port = mkOption {
      type = types.port;
      description = ''
        The local port the service listens on.
      '';
    };

    grpc_addr = mkOption {
      type = types.str;
      default = "0.0.0.0";
    };
    grpc_port = mkOption {
      type = types.port;
      default = 9000;
    };
  };

  config = mkIf (config.secshell.gitea.enable && cfg.enable) (mkMerge [
    # base
    {
      sops = {
        secrets."woodpecker/secret" = { };
        templates."woodpecker/environment-agent".content = ''
          WOODPECKER_AGENT_SECRET=${config.sops.placeholder."woodpecker/secret"}
        '';
      };
    }

    # server
    (mkIf cfg.enableServer {
      sops = {
        secrets = {
          "woodpecker/oidcClientId" = { };
          "woodpecker/oidcSecret" = { };
        };
        templates."woodpecker/environment".content = mkAfter ''
          WOODPECKER_GITEA_CLIENT=${config.sops.placeholder."woodpecker/oidcClientId"}
          WOODPECKER_GITEA_SECRET=${config.sops.placeholder."woodpecker/oidcSecret"}
        '';
      };

      services = {
        woodpecker-server = {
          enable = true;
          environment = {
            WOODPECKER_HOST = "https://${cfg.domain}";
            WOODPECKER_SERVER_ADDR = "127.0.0.1:${toString cfg.internal_port}";
            WOODPECKER_GRPC_ADDR = "${cfg.grpc_addr}:${toString cfg.grpc_port}";
            WOODPECKER_OPEN = "true";

            WOODPECKER_GITEA = "true";
            WOODPECKER_GITEA_URL = config.services.gitea.settings.server.ROOT_URL;
            WOODPECKER_AUTHENTICATE_PUBLIC_REPOS = "true";
          };
          environmentFile = config.sops.templates."woodpecker/environment".path;
        };

        nginx = {
          enable = true;
          virtualHosts."${toString cfg.domain}" = {
            locations = {
              "/".proxyPass = "http://127.0.0.1:${toString cfg.internal_port}";
            };
            serverName = toString cfg.domain;

            # use ACME DNS-01 challenge
            useACMEHost = toString cfg.domain;
            forceSSL = true;
          };
        };
      };
      security.acme.certs."${toString cfg.domain}" = { };
    })

    # agent
    (mkIf cfg.enableAgent {
      services.woodpecker-agents.agents.docker = {
        enable = true;
        extraGroups = [ "podman" ];
        environment = {
          WOODPECKER_SERVER = "${toString cfg.domain}:${toString cfg.grpc_port}";

          WOODPECKER_MAX_WORKFLOWS = "4";

          WOODPECKER_BACKEND = "docker";
          DOCKER_HOST = "unix:///run/podman/podman.sock";
        };
        environmentFile = [ config.sops.templates."woodpecker/environment-agent".path ];
      };

      virtualisation.podman = {
        enable = true;
        defaultNetwork.settings = {
          dns_enabled = true;
        };
        dockerCompat = true;
      };

      # This is needed for podman to be able to talk over dns
      networking.firewall.interfaces."podman0" = {
        allowedUDPPorts = [ 53 ];
        allowedTCPPorts = [ 53 ];
      };

      # Adjust runner service for nix usage
      systemd.services.woodpecker-agent-docker = {
        after = [
          "podman.socket"
        ]
        ++ (lib.optionals cfg.enableServer [
          "woodpecker-server.service"
        ]);
        # might break deployment
        restartIfChanged = false;
        serviceConfig = {
          BindPaths = [ "/run/podman/podman.sock" ];
        };
      };
    })
  ]);
}
