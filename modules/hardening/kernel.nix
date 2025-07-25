{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.secshell.hardening {
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_hardened;
    security = {
      lockKernelModules = lib.mkDefault true;
      protectKernelImage = lib.mkDefault true;
    };
  };
}
