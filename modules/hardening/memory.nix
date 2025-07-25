{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.secshell.hardening {
    security = {
      allowSimultaneousMultithreading = lib.mkDefault false;

      forcePageTableIsolation = lib.mkDefault true;

      # This is required by podman to run containers in rootless mode.
      unprivilegedUsernsClone = lib.mkDefault config.virtualisation.containers.enable;

      virtualisation.flushL1DataCache = lib.mkDefault "always";
    };

    environment = {
      memoryAllocator.provider = lib.mkDefault "scudo";
      variables.SCUDO_OPTIONS = lib.mkDefault "ZeroContents=1";
    };

    boot.kernelParams = [
      # Don't merge slabs
      "slab_nomerge"

      # Overwrite free'd pages
      "page_poison=1"

      # Enable page allocator randomization
      "page_alloc.shuffle=1"

      # Disable debugfs
      "debugfs=off"
    ];
  };
}
