{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.secshell.hardening {
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
  };
}
