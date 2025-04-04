{
  lib,
  ...
}:
{
  boot = {
    initrd.availableKernelModules = [
      "ahci"
      "xhci_pci"
      "usb_storage"
      "sd_mod"
      "sdhci_pci"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    kernelParams = [ ];
    extraModulePackages = [ ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
