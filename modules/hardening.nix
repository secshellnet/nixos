{
  lib,
  pkgs,
  config,
  modulesPath,
  ...
}:
let
  mkDisableOption =
    name:
    lib.mkEnableOption name
    // {
      default = true;
      example = false;
    };
in
{
  options.secshell.hardening = mkDisableOption "hardening";

  imports = [ (modulesPath + "/profiles/hardened.nix") ];

  config = lib.mkIf config.secshell.hardening {
    nix.settings.allowed-users = [ "@wheel" ];
    security.sudo = {
      execWheelOnly = true;
      extraConfig = ''
        Defaults logfile="/var/log/sudo.log"
      '';
    };

    # weird logrotate issue during config check
    # cannot find name for group ID 30000
    # https://discourse.nixos.org/t/logrotate-config-fails-due-to-missing-group-30000/28501
    services.logrotate.checkConfig = false;

    boot = {
      extraModprobeConfig =
        let
          cmd = "${pkgs.coreutils}/bin/true";
          modules = [
            # Unused network protocols
            "sctp"
            "dccp"
            "rds"
            "tipc"
            "n-hdlc"
            "x25"
            "appletalk"
            "can"
            "atm"
            "psnap"
            "p8022"

            # Unused file systems
            "jffs2"
            "hfsplus"
            "udf"

            # Unused interfaces
            "thunderbolt"
            "firewire-core"

            # Firewire
            "sbp2"
            "ohci1394"
            "firewire-ohci"

            # Wifi
            "ath"
            "iwlegacy"
            "iwlwifi"
            "mwifiex"
            "rtlwifi"
          ];
        in
        lib.concatStringsSep "\n" (map (kmod: "install ${kmod} ${cmd}") modules);

      kernel.sysctl = {
        "dev.tty.ldisc_autoload" = lib.mkDefault 0;
        "fs.protected_fifos" = lib.mkDefault 2;
        "fs.protected_regular" = lib.mkDefault 2;
        "fs.protected_hardlinks" = lib.mkDefault 1;
        "fs.protected_symlinks" = lib.mkDefault 1;
        "fs.suid_dumpable" = lib.mkDefault 0;
        "kernel.yama.ptrace_scope" = lib.mkDefault 3;
        "kernel.randomize_va_space" = lib.mkDefault 2;
        "kernel.dmesg_restrict" = lib.mkDefault 1;
        "kernel.perf_event_paranoid" = lib.mkDefault 3;
        "kernel.sysrq" = lib.mkDefault 0;
        "kernel.unprivileged_bpf_disabled" = lib.mkDefault 1;
        "kernel.io_uring_disabled" = lib.mkDefault 2;
        "net.core.bpf_jit_harden" = lib.mkDefault 2;
        "net.ipv4.ip_forward" = lib.mkDefault 0;
        "net.ipv6.conf.all.forwarding" = lib.mkDefault 0;
        "net.ipv6.conf.all.accept_ra" = lib.mkDefault 0;
        "net.ipv6.conf.default.accept_ra" = lib.mkDefault 0;
      };
    };

    fileSystems."/proc" = {
      fsType = "proc";
      device = "proc";
      options = [
        "nosuid"
        "nodev"
        "noexec"
        "hidepid=2"
      ];
      neededForBoot = true;
    };

    services = {
      openssh.settings = {
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
        LogLevel = lib.mkOverride 950 "DEBUG";
      };

      fail2ban = lib.mkIf config.services.openssh.enable {
        enable = true;
        maxretry = 10;
        bantime = "24h";
      };
    };

    security.pam.services.passwd.rules.password = {
      pwquality = {
        control = "required";
        modulePath = "${pkgs.libpwquality.lib}/lib/security/pam_pwquality.so";
        # order BEFORE pam_unix.so
        order = config.security.pam.services.passwd.rules.password.unix.order - 10;
        settings = {
          minlen = lib.mkDefault 12;

          # at least 6 characters must differ from the old password
          difok = lib.mkDefault 6;

          # required characters (at least one digit, lowercase and uppercase letter)
          dcredit = lib.mkDefault (-1);
          lcredit = lib.mkDefault (-1);
          ucredit = lib.mkDefault (-1);
          ocredit = lib.mkDefault 1;

          # no more than 3 repeated characters in a row
          maxrepeat = lib.mkDefault 3;

          enforce_for_root = lib.mkDefault true;
        };
      };
      unix = {
        control = lib.mkForce "required";
        settings.use_authtok = true;
      };
    };
  };
}
