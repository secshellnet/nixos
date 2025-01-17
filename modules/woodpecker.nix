{
  config,
  lib,
  pkgs-unstable,
  ...
}:
{
  options.secshell.gitea.woodpecker = {
    enable = lib.mkEnableOption "woodpecker";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "woodpecker.${toString config.networking.fqdn}";
      defaultText = "woodpecker.\${toString config.networking.fqdn}";
    };
    internal_port = lib.mkOption { type = lib.types.port; };
    grpc_port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
    };
  };
  config = lib.mkIf (config.secshell.gitea.woodpecker.enable && config.secshell.gitea.enable) {
    sops = {
      secrets = {
        "woodpecker/secret" = { };
        "woodpecker/oidcClientId" = { };
        "woodpecker/oidcSecret" = { };
      };
      templates."woodpecker/environment".content = ''
        WOODPECKER_AGENT_SECRET=${config.sops.placeholder."woodpecker/secret"}
        WOODPECKER_GITEA_CLIENT=${config.sops.placeholder."woodpecker/oidcClientId"}
        WOODPECKER_GITEA_SECRET=${config.sops.placeholder."woodpecker/oidcSecret"}
      '';
      templates."woodpecker/environment-agent".content = ''
        WOODPECKER_AGENT_SECRET=${config.sops.placeholder."woodpecker/secret"}
      '';
    };

    services = {
      woodpecker-server = {
        enable = true;
        package = pkgs-unstable.woodpecker-server;
        environment = {
          WOODPECKER_HOST = "https://${config.secshell.gitea.woodpecker.domain}";
          WOODPECKER_SERVER_ADDR = "127.0.0.1:${toString config.secshell.gitea.woodpecker.internal_port}";
          WOODPECKER_GRPC_ADDR = "127.0.0.1:${toString config.secshell.gitea.woodpecker.grpc_port}";
          WOODPECKER_OPEN = "true";

          WOODPECKER_GITEA = "true";
          WOODPECKER_GITEA_URL = config.services.gitea.settings.server.ROOT_URL;
        };
        environmentFile = config.sops.templates."woodpecker/environment".path;
      };

      woodpecker-agents.agents.docker = {
        enable = true;
        package = pkgs-unstable.woodpecker-agent;
        extraGroups = [ "podman" ];
        environment = {
          WOODPECKER_SERVER = "127.0.0.1:${toString config.secshell.gitea.woodpecker.grpc_port}";

          WOODPECKER_MAX_WORKFLOWS = "4";

          WOODPECKER_BACKEND = "docker";
          DOCKER_HOST = "unix:///run/podman/podman.sock";
        };
        environmentFile = [ config.sops.templates."woodpecker/environment-agent".path ];
      };
      nginx = {
        enable = true;
        virtualHosts."${toString config.secshell.gitea.woodpecker.domain}" = {
          locations = {
            "/".proxyPass = "http://127.0.0.1:${toString config.secshell.gitea.woodpecker.internal_port}";
          };
          serverName = toString config.secshell.gitea.woodpecker.domain;

          # use ACME DNS-01 challenge
          useACMEHost = toString config.secshell.gitea.woodpecker.domain;
          forceSSL = true;
        };
      };
    };
    security.acme.certs."${toString config.secshell.gitea.woodpecker.domain}" = { };

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
        "woodpecker-server.service"
      ];
      # might break deployment
      restartIfChanged = false;
      serviceConfig = {
        BindPaths = [ "/run/podman/podman.sock" ];
      };
    };

  };
}
