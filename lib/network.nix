{ lib }:
rec {
  # function to return a random interface name of a system depending of the network implementation
  getAInterfaceName =
    system:
    let
      interfaceNames =
        if system.config.networking.ifstate.enable then
          builtins.map (int: int.name) system.config.networking.ifstate.settings.interfaces
        else if builtins.length (lib.attrNames system.config.networking.interfaces) > 0 then
          lib.attrNames system.config.networking.interfaces
        else
          throw "Unsupported network implementation in use!";
    in
    if builtins.length interfaceNames > 0 then
      builtins.head interfaceNames
    else
      throw "Unable to find network interfaces...";

  # function to get all addresses from a interface
  getAddresses =
    system: interface:
    if system.config.networking.ifstate.enable then
      let
        int = system.config.networking.ifstate.settings.interfaces;
      in
      map (e: builtins.elemAt (lib.splitString "/" e) 0) (
        (builtins.head (builtins.filter (e: e.name == interface) int)).addresses
      )

    else if builtins.length (lib.attrNames system.config.networking.interfaces) > 0 then
      let
        int = system.config.networking.interfaces.${interface};
      in
      map (e: e.address) (int.ipv4.addresses ++ int.ipv6.addresses)

    else
      throw "Unsupported network implementation in use!";

  # function to determine if a string is a valid ipv4 address
  isIPv4 =
    ipString:
    let
      parts = lib.splitString "." ipString;
    in
    lib.length parts == 4
    && lib.all (
      part:
      let
        intValue = lib.toInt part;
      in
      intValue != null && intValue >= 0 && intValue <= 255
    ) parts;

  # function to get the first address from an interface of the system
  getFirstAddrV4 =
    system:
    builtins.head (builtins.filter (e: isIPv4 e) (getAddresses system (getAInterfaceName system)));
  getFirstAddrV6 =
    system:
    builtins.head (builtins.filter (e: !isIPv4 e) (getAddresses system (getAInterfaceName system)));

  /**
    Retrieves an interface configuration by name from the ifstate settings.

    # Type

    ```
    getInterface :: Attrs -> String -> Attrs
    ```

    # Arguments

    config
    : The config of the host.
    interface
    : The name of the interface to retrieve.
  */
  getInterface =
    config: interface:
    builtins.head (
      builtins.filter (int: int.name == "${interface}") config.networking.ifstate.settings.interfaces
    );

  getWgEndpoint =
    config: interface: (builtins.head (getInterface config interface).wireguard.peers).endpoint;
  getWgLocalPort = config: interface: toString (getInterface config interface).wireguard.listen_port;
  getWgRemoteAddr =
    config: interface:
    lib.pipe (getWgEndpoint config interface) [
      (builtins.split ":")
      (builtins.filter (part: part != [ ]))
      lib.lists.init
      (lib.strings.concatStringsSep ":")
      (builtins.replaceStrings [ "[" "]" ] [ "" "" ])
    ];
  getWgRemotePort =
    config: interface:
    lib.pipe (getWgEndpoint config interface) [
      (builtins.split ":")
      lib.lists.last
    ];
  getSitRemoteAddr = config: interface: (getInterface config interface).link.sit_remote;
  getGreRemoteAddr = config: interface: (getInterface config interface).link.gre_remote;
  getVxlanRemoteAddr = config: interface: (getInterface config interface).link.vxlan_group;
  getVxlanRemotePort = config: interface: toString (getInterface config interface).link.vxlan_port;
}
