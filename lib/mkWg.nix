{
  lib,
  pkgs,
  libS,
}:
{
  config,
  ## Wireguard Configuration
  # The local wireguard interface, which will be created by this connection (max 15 chars)
  wgInterface ? "wg0",
  # [optional] The altname property for this link
  wgInterfaceAlias ? null,
  # The local listening port, depends on the instance of the wireguard interface
  wgListenPort ?
    51820 + lib.toInt (builtins.head (builtins.tail (lib.strings.splitString "wg" wgInterface))),
  # The sops path to the private key (e.g. wireguard/private-key/wg0-NAME)
  wgPrivateKeySops,
  # [optional] The sops path to the preshared key (e.g. wireguard/psk/wg0-NAME)
  wgPskSops ? null,
  # The public key of the remote peer
  wgRemotePublicKey,
  # [optional] The remote wireguard endpoint
  wgEndpoint ? null,
  wgPersistentKeepalive ? 1,
  wgAllowedIps ? [
    "0.0.0.0/0"
    "::/0"
  ],
  # The wireguard tunnel addresses and dns server to use
  wgAddr ? [ ],
  # [optional] The network namespace via which the tunnel will be bind (e.g. outside)
  wgBindNetNs ? null,
  # [optional] The vrf to set as msater for  the wireguard interface
  wgMaster ? null,
  wgWanInterfaces ? "ens18",
}:
let
  inherit (lib) mkIf;
  inherit (libS.net) getWgLocalPort getWgRemoteAddr getWgRemotePort;
in
{
  sops.secrets = {
    "${wgPrivateKeySops}" = { };
  }
  // (lib.optionalAttrs (wgPskSops != null) {
    "${wgPskSops}" = { };
  });

  networking = {
    ifstate.settings = {
      interfaces = [
        {
          name = wgInterface;
          addresses = wgAddr;
          link = {
            state = "up";
            kind = "wireguard";
            bind_netns = mkIf (wgBindNetNs != null) wgBindNetNs;
            master = mkIf (wgMaster != null) wgMaster;
          };
          wireguard = {
            listen_port = wgListenPort;
            private_key = "!include ${config.sops.secrets."${wgPrivateKeySops}".path}";
            peers = [
              {
                public_key = wgRemotePublicKey;
                preshared_key = mkIf (wgPskSops != null) "!include ${config.sops.secrets."${wgPskSops}".path}";
                allowedips = wgAllowedIps;
                endpoint = mkIf (wgEndpoint != null) wgEndpoint;
                persistent_keepalive_interval = wgPersistentKeepalive;
              }
            ];
          };
        }
      ];
    };

    nftables.tables.nixos-fw.content =
      if wgEndpoint != null then
        let
          wgRemoteAddr = getWgRemoteAddr config wgInterface;
          ipFamily = if libS.net.isIPv4 wgRemoteAddr then "ip" else "ip6";
        in
        ''
          chain input-allow {
            iifname ${wgWanInterfaces} ${ipFamily} saddr ${wgRemoteAddr} udp dport ${getWgLocalPort config wgInterface} accept
          };
          chain output-allow {
            oifname ${wgWanInterfaces} ${ipFamily} daddr ${wgRemoteAddr} udp dport ${getWgRemotePort config wgInterface} accept
          };
        ''
      else
        ''
          chain input-allow {
            iifname ${wgWanInterfaces} udp dport ${getWgLocalPort config wgInterface} accept
          };
        '';
  };

  # set alternative name for simple interface identification
  systemd.services.ifstate.postStart = lib.mkIf (wgInterfaceAlias != null) ''
    ${pkgs.iproute2}/bin/ip link property add dev ${wgInterface} altname ${wgInterfaceAlias} || true
  '';
}
