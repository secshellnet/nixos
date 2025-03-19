{
  lib,
  pkgs,
  config,
  ...
}:
{
  # - nftables doesn't support network namespaces yet
  # - network namespaces can be created using ifstate
  # - Using this implementation the nftables ruleset is being distribute
  #   to all specified network namespaces. Usually only unmanaged network
  #   namespaces (not being used for a nixos-container) should be specified
  #   here.
  # - Warning: This comes with the limitation, that network interface must
  #   have a unique name (even in different netns)

  options.secshell.firewall.netns = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ ];
    description = ''
      Network namespaces on which the nftables ruleset should be applied
      - Network namespaces must have been created by ifstate
      - The firewall configuration must be done using nftables
      - Warning: All network interfaces must have a unique name, because the same
        ruleset is applied on all given network namespaces.
    '';
  };

  config.systemd.services = builtins.listToAttrs (
    map (key: {
      name = "nftables@${key}";
      value =
        let
          cfg = config.systemd.services.nftables;
          map' = f: x: if lib.isList x then map f x else f x;
          mapFunc = file: "${lib.getExe' pkgs.iproute2 "ip"} netns exec %i ${file}";
        in
        {
          inherit (cfg)
            conflicts
            wants
            wantedBy
            reloadIfChanged
            ;
          description = "nftables firewall for network namespace %i";
          before = [ "network.target" ];
          after = [
            "network-setup.service"
            "network-pre.target"
            # netns must exist, before firewall rules can be applied
            "ifstate.service"
          ];
          serviceConfig =
            {
              inherit (cfg.serviceConfig) Type RemainAfterExit StateDirectory;
            }
            // builtins.listToAttrs (
              map
                (key: {
                  name = key;
                  value = map' mapFunc cfg.serviceConfig.${key};
                })
                [
                  "ExecStart"
                  "ExecStartPost"
                  "ExecStop"
                  "ExecReload"
                ]
            );
          unitConfig.DefaultDependencies = false;
        };
    }) config.secshell.firewall.netns
  );
}
