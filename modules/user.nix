{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    types
    mkOption
    length
    ;
in
{
  options.secshell = {
    keysDir = mkOption {
      type = types.nullOr types.path;
      default = mkIf (length config.secshell.users == 0) null;
      description = "The directory containing the public ssh keys of the users configured in secshell.users.";
    };
    users = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "The users that should be created.";
    };
  };
  config = {
    sops.secrets = {
      "rootPassword".neededForUsers = true;
    }
    // lib.foldl' (set: acc: acc // set) { } (
      map (username: { "${username}Password".neededForUsers = true; }) config.secshell.users
    );

    users = {
      mutableUsers = false;
      users = {
        root = {
          hashedPasswordFile = config.sops.secrets."rootPassword".path;
          openssh.authorizedKeys.keyFiles = lib.filter (path: builtins.pathExists path) (
            map (username: /${config.secshell.keysDir}/${username}.ssh) config.secshell.users
          );
        };
      }
      // builtins.listToAttrs (
        map (
          username:
          lib.nameValuePair username {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            hashedPasswordFile = config.sops.secrets."${username}Password".path;
            openssh.authorizedKeys.keyFiles =
              lib.mkIf (lib.pathExists /${config.secshell.keysDir}/${username}.ssh)
                [ /${config.secshell.keysDir}/${username}.ssh ];
          }
        ) config.secshell.users
      );
    };

    # Show fqdn instead of short hostname in ps1
    environment.etc."bashrc.local".text = ''
      if [ "$EUID" -eq 0 ]; then
        export PS1='\n\[\033[1;31m\][\[\e]0;\u@'${config.networking.fqdnOrHostName}': \w\a\]\u@'${config.networking.fqdnOrHostName}':\w]\$\[\033[0m\] '
      else
        export PS1='\[\033[01;32m\]\u@'${config.networking.fqdnOrHostName}'\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$ '
      fi
    '';
  };
}
