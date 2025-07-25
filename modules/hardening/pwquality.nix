{
  lib,
  pkgs,
  config,
  ...
}:
{
  config = lib.mkIf config.secshell.hardening {
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
