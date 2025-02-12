{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  cfg = config.secshell.gitea.woodpecker;
in
{
  config = lib.mkIf (cfg.enable && cfg.enableAgent) {
    sops = {
      secrets = {
        "woodpecker/secret" = { };
      };
      templates."woodpecker/environment-agent".content = ''
        WOODPECKER_AGENT_SECRET=${config.sops.placeholder."woodpecker/secret"}
      '';
    };

    services.woodpecker-agents.agents.docker = {
      enable = true;
      package = pkgs-unstable.woodpecker-agent;
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
      ] ++ (lib.optionals cfg.enableServer [
        "woodpecker-server.service"
      ]);
      # might break deployment
      restartIfChanged = false;
      serviceConfig = {
        BindPaths = [ "/run/podman/podman.sock" ];
      };
    };
  };
}
