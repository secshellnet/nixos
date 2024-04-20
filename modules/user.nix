{ config
, pkgs
, lib
, ...
}: {
  options.secshell = {
    keysDir = lib.mkOption {
      type = lib.types.path;
    };
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };
  config = {
    sops.secrets = {
      "rootPassword".neededForUsers = true;
    } // lib.foldl' (set: acc: acc // set) {} (map (username: {
      "${username}Password".neededForUsers = true;
    }) config.secshell.users);

    users.users = {
      root = {
        hashedPasswordFile = config.sops.secrets."rootPassword".path;
        openssh.authorizedKeys.keyFiles = lib.filter (path: builtins.pathExists path) (map(username: /${config.secshell.keysDir}/${username}.ssh) config.secshell.users);
      };
    } // builtins.listToAttrs (map (username: lib.nameValuePair username {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPasswordFile = config.sops.secrets."${username}Password".path;
      openssh.authorizedKeys.keyFiles = lib.mkIf (lib.pathExists /${config.secshell.keysDir}/${username}.ssh) [ /${config.secshell.keysDir}/${username}.ssh ];
    }) config.secshell.users);

    # Show fqdn instead of short hostname in ps1
    environment.etc."bashrc.local".text = ''
      if [ "$EUID" -eq 0 ]; then
        export PS1='\n\[\033[1;31m\][\[\e]0;\u@'$(hostname -f)': \w\a\]\u@'$(hostname -f)':\w]\$\[\033[0m\] '
      else
        export PS1='\[\033[01;32m\]\u@'$(hostname -f)'\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$ '
      fi
    '';

  };
}
