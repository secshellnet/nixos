{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption types;
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
    };

    internal_port = mkOption { type = types.port; };

    grpc_addr = mkOption {
      type = types.str;
      default = "0.0.0.0";
    };
    grpc_port = mkOption {
      type = types.port;
      default = 9000;
    };
  };

  imports = [
    ./woodpecker-server.nix
    ./woodpecker-agent.nix
  ];
}
