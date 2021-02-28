{ config, lib, options, pkgs, ... }:
let
  cfg = config.services.kanidm;
  settingsFormat = (pkgs.formats.toml { });
  serverConfigFile = settingsFormat.generate "server.toml" (cfg.serverSettings // {
    db_path = cfg.db_path;
  });
  clientConfigFile = settingsFormat.generate "kanidm-config.toml" cfg.clientSettings;
  unixConfigFile = settingsFormat.generate "kanidm-unixd.toml" cfg.unixSettings;
in
{
  options = {
    services.kanidm = {
      enable = lib.mkEnableOption "the kanidm server";
      enablePam = lib.mkEnableOption "the pam and nsswitch integration of kanidm";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.kanidm;
        description = "Which kanidm package to use.";
      };

      db_path = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/kanidm/kanidm.db";
        description = "Path to the kanidm database.";
      };

      serverSettings = lib.mkOption {
        type = with lib.types; attrsOf anything;
        # TODO description, example
        description = ''
          Configure the kanidmd server.
          https://github.com/kanidm/kanidm/blob/master/kanidm_book/src/installing_the_server.md#configuration
        '';
      };

      clientSettings = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = {};
        # TODO description, example
        description = ''
          Configure kanidm clients.
          https://github.com/kanidm/kanidm/blob/master/kanidm_book/src/client_tools.md#kandim-configuration
        '';
      };

      unixSettings = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = {};
        # TODO description, example
        description = ''
          Configure kanidm unix daemon.
          https://github.com/kanidm/kanidm/blob/master/kanidm_book/src/pam_and_nsswitch.md#the-unix-daemon
        '';
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ Flakebi ];

  config = lib.mkIf (cfg.enable || cfg.enablePam) {
    assertions =
      [
        {
          assertion = !cfg.enable || ((cfg.serverSettings.tls_chain or null) == null) || (!lib.isStorePath cfg.serverSettings.tls_chain);
          message = ''
            <option>services.kanidm.serverSettings.tls_chain</option> points to
            a file in the Nix store. You should use a quoted absolute path to
            prevent this.
          '';
        }
        {
          assertion = !cfg.enable || ((cfg.serverSettings.tls_key or null) == null) || (!lib.isStorePath cfg.serverSettings.tls_key);
          message = ''
            <option>services.kanidm.serverSettings.tls_key</option> points to
            a file in the Nix store. You should use a quoted absolute path to
            prevent this.
          '';
        }
        {
          assertion = !cfg.enablePam || options.services.kanidm.clientSettings.isDefined;
          message = ''
            <option>services.kanidm.clientSettings</option> needs to be configured
            for the PAM daemon to connect to the kanidmd server.
          '';
        }
      ];

    environment.systemPackages = [ cfg.package ];

    systemd.services.kanidm = lib.mkIf cfg.enable {
      description = "kanidm identity management daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        StateDirectory = "kanidm";
        StateDirectoryMode = "0700";
        ExecStart = "${cfg.package}/bin/kanidmd server -c ${serverConfigFile}";

        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        BindReadOnlyPaths = [
          "/nix/store"
          "-/etc/resolv.conf"
          "-/etc/nsswitch.conf"
          "-/etc/hosts"
          "-/etc/localtime"
        ];
        CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
        # ProtectClock= adds DeviceAllow=char-rtc r
        DeviceAllow = "";
        DynamicUser = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        # Port needs to be exposed to the host network
        #PrivateNetwork = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectSystem = "strict";
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" "~@privileged @resources @setuid @keyring" ];
        TemporaryFileSystem = "/:ro";
        UMask = "0066";
      };
      environment.RUST_LOG = "info";
    };

    systemd.services.kanidm-unixd = lib.mkIf cfg.enablePam {
      description = "kanidm PAM daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartTriggers = [ unixConfigFile clientConfigFile ];
      serviceConfig = {
        CacheDirectory = "kanidm-unixd";
        CacheDirectoryMode = "0700";
        RuntimeDirectory = "kanidm-unixd";
        ExecStart = "${cfg.package}/bin/kanidm_unixd";

        BindReadOnlyPaths = [
          "/nix/store"
          "-/etc/resolv.conf"
          "-/etc/nsswitch.conf"
          "-/etc/hosts"
          "-/etc/localtime"
          "-/etc/kanidm"
        ];
        CapabilityBoundingSet = "";
        # ProtectClock= adds DeviceAllow=char-rtc r
        DeviceAllow = "";
        DynamicUser = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        # Needs to connect to kanidmd
        #PrivateNetwork = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectSystem = "strict";
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" "~@privileged @resources @setuid @keyring" ];
        TemporaryFileSystem = "/:ro";
        UMask = "0066";
      };
      environment.RUST_LOG = "info";
    };

    systemd.services.kanidm-unixd-tasks = lib.mkIf cfg.enablePam {
      description = "kanidm PAM home management daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "kanidm-unixd.service" ];
      partOf = [ "kanidm-unixd.service" ];
      restartTriggers = [ unixConfigFile clientConfigFile ];
      serviceConfig = {
        RuntimeDirectory = "kanidm-unixd";
        ExecStart = "${cfg.package}/bin/kanidm_unixd_tasks";

        BindReadOnlyPaths = [
          "/nix/store"
          "-/etc/resolv.conf"
          "-/etc/nsswitch.conf"
          "-/etc/hosts"
          "-/etc/localtime"
        ];
        BindPaths = [
          # To manage home directories
          "/home"
          # To connect to kanidm-unixd
          # Unfortunately, this somehow removes /run/kanidm-unixd/ when this service is stopped,
          # so kanidm-unixd needs to be restarted.
          "/run/kanidm-unixd/task_sock"
        ];
        CapabilityBoundingSet = "";
        # ProtectClock= adds DeviceAllow=char-rtc r
        DeviceAllow = "";
        # Needs to run as root
        #DynamicUser = true;
        IPAddressDeny = "any";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateNetwork = true;
        PrivateTmp = true;
        # Need access to users
        #PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        # Need access to home directories
        #ProtectHome = true;
        ProtectHostname = true;
        ProtectSystem = "strict";
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = [ "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" "~@privileged @resources @setuid @keyring" ];
        TemporaryFileSystem = "/:ro";
        UMask = "0066";
      };
      environment.RUST_LOG = "info";
    };

    # These paths are hardcoded
    environment.etc = lib.mkMerge [
      (lib.mkIf options.services.kanidm.clientSettings.isDefined {
        "kanidm/config".source = clientConfigFile;
      })
      (lib.mkIf cfg.enablePam {
        "kanidm/unixd".source = unixConfigFile;
      })
    ];

    system.nssModules = lib.mkIf cfg.enablePam [ pkgs.kanidm ];

    system.nssDatabases.group = lib.optional cfg.enablePam "kanidm";
    system.nssDatabases.passwd = lib.optional cfg.enablePam "kanidm";
  };
}
