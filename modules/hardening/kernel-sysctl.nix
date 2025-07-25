{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.secshell.hardening {
    boot.kernel.sysctl = {
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

      # Hide kptrs even for processes with CAP_SYSLOG
      "kernel.kptr_restrict" = lib.mkOverride 500 2;

      # Disable bpf() JIT (to eliminate spray attacks)
      "net.core.bpf_jit_enable" = lib.mkDefault false;

      # Disable ftrace debugging
      "kernel.ftrace_enabled" = lib.mkDefault false;

      # Enable strict reverse path filtering (that is, do not attempt to route
      # packets that "obviously" do not belong to the iface's network; dropped
      # packets are logged as martians).
      "net.ipv4.conf.all.log_martians" = lib.mkDefault true;
      "net.ipv4.conf.all.rp_filter" = lib.mkDefault "1";
      "net.ipv4.conf.default.log_martians" = lib.mkDefault true;
      "net.ipv4.conf.default.rp_filter" = lib.mkDefault "1";

      # Ignore broadcast ICMP (mitigate SMURF)
      "net.ipv4.icmp_echo_ignore_broadcasts" = lib.mkDefault true;

      # Ignore incoming ICMP redirects (note: default is needed to ensure that the
      # setting is applied to interfaces added after the sysctls are set)
      "net.ipv4.conf.all.accept_redirects" = lib.mkDefault false;
      "net.ipv4.conf.all.secure_redirects" = lib.mkDefault false;
      "net.ipv4.conf.default.accept_redirects" = lib.mkDefault false;
      "net.ipv4.conf.default.secure_redirects" = lib.mkDefault false;
      "net.ipv6.conf.all.accept_redirects" = lib.mkDefault false;
      "net.ipv6.conf.default.accept_redirects" = lib.mkDefault false;

      # Ignore outgoing ICMP redirects (this is ipv4 only)
      "net.ipv4.conf.all.send_redirects" = lib.mkDefault false;
      "net.ipv4.conf.default.send_redirects" = lib.mkDefault false;
    };
  };
}
