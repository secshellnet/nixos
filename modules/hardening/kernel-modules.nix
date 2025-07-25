{
  lib,
  pkgs,
  config,
  ...
}:
{
  config = lib.mkIf config.secshell.hardening {
    boot.extraModprobeConfig =
      let
        cmd = "${pkgs.coreutils}/bin/true";
        modules = [
          # Obscure network protocols
          "ax25"
          "netrom"
          "rose"

          # Old or rare or insufficiently audited filesystems
          "adfs"
          "affs"
          "bfs"
          "befs"
          "cramfs"
          "efs"
          "erofs"
          "exofs"
          "freevxfs"
          "f2fs"
          "hfs"
          "hpfs"
          "jfs"
          "minix"
          "nilfs2"
          "ntfs"
          "omfs"
          "qnx4"
          "qnx6"
          "sysv"
          "ufs"

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
  };
}
