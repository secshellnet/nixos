{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.services.postgresql = with lib; {
    userPasswords = mkOption {
      type = types.attrsOf types.path;
      default = { };
    };
    expose = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config =
    let
      cfg = config.services.postgresql;
    in
    lib.mkIf config.services.postgresql.enable {
      services.postgresql = {
        package = pkgs.postgresql_16;
        enableTCPIP = true; # do we need this for any service? can it just be config.services.postgresql.expose?
        ensureUsers = map (db: {
          name = db;
          ensureDBOwnership = true;
        }) cfg.ensureDatabases;

        authentication = lib.mkForce (
          ''
            local all all peer
            host all all all scram-sha-256
          ''
          + "\n"
          + (lib.optionalString config.services.postgresql.expose ''
            host all all 0.0.0.0/0   scram-sha-256 
            host all all ::/0   scram-sha-256
          '')
        );
      };

      # TODO check if enabled, otherwise configure nftables
      networking.firewall.allowedTCPPorts = lib.mkIf config.services.postgresql.expose [ 5432 ];

      systemd.services.postgresql.postStart = lib.mkAfter ''
        $PSQL -tA <<'EOF'
          DO $$
          DECLARE password TEXT;
          BEGIN
            ${
              builtins.concatStringsSep "\n" (
                lib.mapAttrsToList (name: passwordFile: ''
                  password := trim(both from replace(pg_read_file('${passwordFile}'), E'\n', '''));
                  EXECUTE format('ALTER ROLE "${name}" WITH PASSWORD '''%s''';', password);
                '') cfg.userPasswords
              )
            }
          END $$;
        EOF
      '';
    };
}
