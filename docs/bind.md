# bind

## RDNS
You can setup bind to serve a reverse dns zone, in this configuration the secshell module 
overrides the bind9 version for security reasons. By default, also the bind zone statistics 
and the prometheus bind exporter are being enabled, so that the monitoring can collect this
data. If you don't want the bind version to be obscured or do not want the prometheus exporter
you can stick to the official bind module, which basicly works out of the box for this type of
configuration.
```nix
{
  secshell.bind.enable = true;
  services.bind = {
    zones = {
      "178.168.192.in-addr.arpa" = {
        master = true;
        file = ./178.168.192.in-addr.arpa;
      };
    };
  };
}
```

## Forwarding
In addition to the features, explained in the previous example, for forwarding, this module
enables recursion and sets other options in the bind configuration, required to be run as
dns forwarder. In the future it should simplify the process of setting up dnssec.
```nix
{
  secshell.bind.enable = true;
  services.bind = {
    zones = {
      "example.com" = {
        master = true;
        file = pkgs.writeText "zone-example.com.conf" ''
          $TTL 1800
          @                 IN   SOA      example.com. zonemaster.example.com (
                                            2024091000 ; serial number
                                            1d         ; refresh
                                            30m        ; update retry
                                            1w         ; expiry
                                            1h )       ; negative caching
                            IN   NS       ns1.example.com
                            IN   NS       ns2.example.com
          ; your records
        '';
      };
    };
    forwarders = [ "1.1.1.1" "1.0.0.1" ];
    cacheNetworks = [ "0.0.0.0/0" ];
    forward = "only";
  };
}
```

### Forward zone to another nameserver
```nix
      extraConfig = ''
        zone "example.net" {
          type forward;
          forwarders { 87.65.43.21; };
        };
      '';
```

### Response Policy Zone
Response Policy Zone (RPZ) allows DNS administrators to block, redirect, or modify DNS responses
based on security policies. It's commonly used to block access to malicious domains, filter unwanted
content, and prevent communication with harmful servers. RPZ provides an extra layer of DNS-based
security by controlling domain resolution behavior.

We're using RPZ to rewrite DNS records for public services accessed by clients within the network.
For instance, Keycloak, typically accessed over the internet, is resolved internally, enabling access
to the master realm, which is used for administrative purposes and blocked from external access.

For more information see [www.isc.org/docs/BIND_RPZ.pdf](https://www.isc.org/docs/BIND_RPZ.pdf)
```nix
{
  secshell.bind.enable = true;
  services.bind = {
    zones = {
      "rpz" = {
        master = true;
        file = pkgs.writeText "rpz.conf" ''
          $TTL 1800
          @                 IN   SOA      localhost. root.localhost (
                                            2024091000 ; serial number
                                            1h         ; refresh
                                            30m        ; update retry
                                            1w         ; expiry
                                            30m )      ; negative caching

          ; define your normal nameservers here
                            IN   NS       ns1.example.com
                            IN   NS       ns2.example.com

          ; overrides
          auth.github.com   IN   A        12.34.56.78
        '';
      };
    };
    extraOptions = ''
      response-policy { zone "rpz"; };
    '';
  };
}
```
