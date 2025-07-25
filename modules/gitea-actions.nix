{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.secshell.gitea-actions;
  storeDeps = pkgs.buildEnv {
    name = "store-deps";
    paths =
      (with pkgs; [
        bash
        cacert
        coreutils
        curl
        findutils
        gawk
        git
        gnugrep
        jq
        yq-go
        nix
        nodejs
        openssh
        rsync
      ])
      ++ cfg.storeDependencies;
  };
in
{
  options = {
    secshell.gitea-actions = {
      enable = lib.mkEnableOption "gitea-actions";
      numInstances = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 2;
        description = "Number of instances of the gitea-actions-runner service to create";
      };

      giteaServer = lib.mkOption {
        type = lib.types.str;
        default = config.services.gitea.settings.server.ROOT_URL;
        defaultText = "\${toString config.services.gitea.settings.server.ROOT_URL}";
        description = "The gitea server to serve gitea actions for.";
      };

      storeDependencies = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          # custom tools required in ci pipeline
          nixfmt-rfc-style
          deadnix
          gitleaks
          netcat
          gnused
          gnupg
          sops
          mkpasswd
        ];
        description = "List of packages to symlink into the container";
      };

      additionalFlakeConfig = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "accept-flake-config = true";
        description = "Additional configuration to add to the nix.conf file";
      };

      kvm = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable KVM passthrough for the container";
      };

      containerPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "/var/lib/gitea-actions-runner";
        example = "zroot/root/podman";
        description = "Path to the container storage";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # create a user to run nix ci jobs
      {
        users = {
          groups.gitea-actions = { };
          users.gitea-actions = {
            group = "gitea-actions";
            description = "Used for running nix ci jobs";
            home = "/run/gitea-runner-nix-image";
            isSystemUser = true;
          };
        };
      }
      # provde the podman image declaratively
      {
        sops.secrets."gitea-actions/password" = { };

        systemd.services.gitea-runner-nix-image = {
          wantedBy = [ "multi-user.target" ];
          after = [ "podman.service" ];
          requires = [ "podman.service" ];
          script = ''
            set -eu -o pipefail
            mkdir -p etc/nix

            # Create an unpriveleged user that we can use also without the run-as-user.sh script
            touch etc/passwd etc/group
            groupid=$(cut -d: -f3 < <(getent group gitea-actions))
            userid=$(cut -d: -f3 < <(getent passwd gitea-actions))
            groupadd --prefix $(pwd) --gid "$groupid" gitea-actions
            useradd --prefix $(pwd) -p "$(cat ${
              config.sops.secrets."gitea-actions/password".path
            })" -m -d /tmp -u "$userid" -g "$groupid" -G gitea-actions gitea-actions

            cat <<NIX_CONFIG > etc/nix/nix.conf
            experimental-features = nix-command flakes
            ${cfg.additionalFlakeConfig}
            NIX_CONFIG

            cat <<NSSWITCH > etc/nsswitch.conf
            passwd:    files mymachines systemd
            group:     files mymachines systemd
            shadow:    files

            hosts:     files mymachines dns myhostname
            networks:  files

            ethers:    files
            services:  files
            protocols: files
            rpc:       files
            NSSWITCH

            # list the content as it will be imported into the container
            tar -cv . | tar -tvf -
            tar -cv . | podman import - gitea-runner-nix
          '';

          path = [
            config.virtualisation.podman.package
            pkgs.getent
            pkgs.gnutar
            pkgs.shadow
          ];

          serviceConfig = {
            RuntimeDirectory = "gitea-runner-nix-image";
            WorkingDirectory = "/run/gitea-runner-nix-image";
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };
      }
      # spawn gitea actions runner instances
      {
        services.gitea-actions-runner.instances =
          lib.genAttrs (builtins.genList (n: "nix${builtins.toString n}") cfg.numInstances)
            (iname: {
              enable = true;
              name = "nixos-runner";
              url = cfg.giteaServer;
              tokenFile = "/var/lib/gitea-registration/gitea-runner-${iname}-token";
              labels = [ "nix:docker://gitea-runner-nix" ];
              settings.container = {
                options = "-e NIX_BUILD_SHELL=/bin/bash -e PAGER=cat -e PATH=/bin -e SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt${lib.optionalString cfg.kvm " --device /dev/kvm"} -v /nix:/nix -v ${storeDeps}/bin:/bin -v ${storeDeps}/etc/ssl:/etc/ssl --user gitea-actions";
                network = "host";
                valid_volumes = [
                  "/nix"
                  "${storeDeps}/bin"
                  "${storeDeps}/etc/ssl"
                ];
              };
            });

        # harden and ensure nix image has been created
        systemd.services =
          lib.genAttrs (builtins.genList (n: "gitea-runner-nix${builtins.toString n}") cfg.numInstances)
            (name: {
              after = [
                "gitea-runner-nix-image.service"
              ];

              requires = [
                "gitea-runner-nix-image.service"
              ];

              # ensure a gitea runner token exists
              unitConfig.ConditionPathExists = [ "/var/lib/gitea-registration/${name}-token" ];

              serviceConfig = {
                AmbientCapabilities = "";
                CapabilityBoundingSet = "";
                DeviceAllow = "";
                NoNewPrivileges = true;
                PrivateDevices = true;
                PrivateMounts = true;
                PrivateTmp = true;
                PrivateUsers = true;
                ProtectClock = true;
                ProtectControlGroups = true;
                ProtectHome = true;
                ProtectHostname = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectSystem = "strict";
                RemoveIPC = true;
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                UMask = "0066";
                ProtectProc = "invisible";
                PrivateNetwork = false;
                MemoryDenyWriteExecute = false;
                ProcSubset = "all";
                LockPersonality = false;
                DynamicUser = true;
                SystemCallFilter = [
                  "~@clock"
                  "~@cpu-emulation"
                  "~@module"
                  "~@mount"
                  "~@obsolete"
                  "~@privileged"
                  "~@raw-io"
                  "~@reboot"
                  "~@swap"
                  "~capset"
                  "~setdomainname"
                  "~sethostname"
                ];

                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                  "AF_UNIX"
                  "AF_NETLINK"
                ];
              };
            });

        # podman containers with network isolation require some kernel modules
        boot.kernelModules = [
          "af_packet"
          "nf_nat"
          "nft_chain_nat"
          "nft_compat"
          "overlay"
          "veth"
          "x_tables"
          "xt_addrtype"
          "xt_comment"
          "xt_conntrack"
          "xt_mark"
          "xt_MASQUERADE"
        ];

        # podman containers with network isolation require network access
        boot.kernel.sysctl = {
          "net.ipv4.ip_forward" = lib.mkOverride 920 1;
          "net.ipv6.conf.all.forwarding" = lib.mkOverride 920 1;
        };

        virtualisation = {
          podman.enable = true;
          containers.containersConf.settings.containers.dns_servers =
            lib.mkDefault config.networking.nameservers;
        };
      }
      # create gitea runner tokens using gitea cli if ci pipeline is running on the same host as gitea
      (lib.mkIf config.services.gitea.enable {
        systemd.services =
          lib.genAttrs (builtins.genList (n: "gitea-runner-nix${toString n}-token") cfg.numInstances)
            (name: {
              wantedBy = [ "multi-user.target" ];
              after = lib.optional config.services.gitea.enable "gitea.service";
              unitConfig.ConditionPathExists = [ "!/var/lib/gitea-registration/${name}-token" ];
              script = ''
                set -euo pipefail
                token=$(${lib.getExe config.services.gitea.package} actions generate-runner-token)
                echo "TOKEN=$token" > /var/lib/gitea-registration/${name}
              '';

              environment = {
                GITEA_CUSTOM = "/var/lib/gitea/custom";
                GITEA_WORK_DIR = "/var/lib/gitea";
              };

              serviceConfig = {
                User = "gitea";
                Group = "gitea";
                StateDirectory = "gitea-registration";
                Type = "oneshot";
                RemainAfterExit = true;
              };
            });
      })
      # use sops secrets for gitea runner tokens if not on the same host as the gitea instance
      (lib.mkIf (!config.services.gitea.enable) {
        sops = {
          secrets."gitea-runner-token" = { };
          templates =
            lib.genAttrs (builtins.genList (n: "gitea-runner-nix${toString n}-token") cfg.numInstances)
              (name: {
                content = ''
                  TOKEN=${config.sops.placeholder."gitea-runner-token"}
                '';
                path = "/var/lib/gitea-registration/${name}";
              });
        };
      })
    ]
  );
}
