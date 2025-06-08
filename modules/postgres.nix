{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.postgresql;
  inherit (lib)
    mkIf
    types
    mkOption
    mkForce
    optionalString
    mkAfter
    ;
in
{
  options.services.postgresql = {
    userPasswords = mkOption {
      type = types.attrsOf types.path;
      default = { };
    };
    expose = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    services.postgresql = {
      package = pkgs.postgresql_16;
      enableTCPIP = cfg.expose;
      ensureUsers = map (db: {
        name = db;
        ensureDBOwnership = true;
      }) cfg.ensureDatabases;

      authentication = mkForce (
        ''
          local all all peer
          host all all all scram-sha-256
        ''
        + "\n"
        + (optionalString cfg.expose ''
          host all all 0.0.0.0/0   scram-sha-256
          host all all ::/0   scram-sha-256
        '')
      );
    };

    # TODO check if enabled, otherwise configure nftables
    networking.firewall.allowedTCPPorts = mkIf cfg.expose [ 5432 ];

    systemd.services.postgresql.postStart = mkAfter ''
      $PSQL -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
          ${builtins.concatStringsSep "\n" (
            lib.mapAttrsToList (name: passwordFile: ''
              password := trim(both from replace(pg_read_file('${passwordFile}'), E'\n', '''));
              EXECUTE format('ALTER ROLE "${name}" WITH PASSWORD '''%s''';', password);
            '') cfg.userPasswords
          )}
        END $$;
      EOF
    '';
  };
}
