{ lib
, pkgs
, config
, modulesPath
, ...
}: let
  mkDisableOption = name: lib.mkEnableOption name // {
    default = true;
    example = false;
  };
in {
  options.secshell.hardening = mkDisableOption "hardening";

  imports = [ (modulesPath + "/profiles/hardened.nix") ];

  config = lib.mkIf config.secshell.hardening {
    nix.settings.allowed-users = [ "@wheel" ];
    security.sudo.execWheelOnly = true;

    boot = {
      kernelPackages = pkgs.linuxPackages;  # hardened kernel is currently broken

      extraModprobeConfig = let
        cmd = "${pkgs.coreutils-full}/bin/true";
      in ''
        # Unused network protocols
        install sctp ${cmd}
        install dccp ${cmd}
        install rds ${cmd}
        install tipc ${cmd}
      '';

      kernel.sysctl = {
        "dev.tty.ldisc_autoload" = lib.mkDefault 0;
        "fs.protected_fifos" = lib.mkDefault 2;
        "fs.protected_regular" = lib.mkDefault 2;
        "fs.suid_dumpable" = lib.mkDefault 0;
        "kernel.dmesg_restrict" = lib.mkDefault 1;
        "kernel.perf_event_paranoid" = lib.mkDefault 3;
        "kernel.sysrq" = lib.mkDefault 0;
        "kernel.unprivileged_bpf_disabled" = lib.mkDefault 1;
        "net.core.bpf_jit_harden" = lib.mkDefault 2;
        "net.ipv4.ip_forward" = lib.mkDefault 0;
        "net.ipv6.conf.all.forwarding" = lib.mkDefault 0;
        "net.ipv6.conf.all.accept_ra" = lib.mkDefault 0;
        "net.ipv6.conf.default.accept_ra" = lib.mkDefault 0;
      };
    };

    services.openssh = {
      settings = {
        PermitRootLogin = lib.mkDefault "no";
        PasswordAuthentication = lib.mkDefault false;
        AllowTcpForwarding = lib.mkDefault false;
        MaxAuthTries = lib.mkDefault 6;
        MaxSessions = lib.mkDefault 8;
        TCPKeepAlive = lib.mkDefault false;
        AllowAgentForwarding = lib.mkDefault false;
        ClientAliveCountMax = lib.mkDefault 2;
        LoginGraceTime = lib.mkDefault 30;
        AllowUsers = lib.mkDefault ([ "root" ] ++ config.secshell.users);
        MaxStartups = lib.mkDefault "10:30:60";
      };
    };
  };
}
