{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.keycloak;

in
{
  options.services.keycloak = {
    enable = mkEnableOption "Keycloak";

    groups = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Groups to which the keycloak user should be added.
      '';
    };

    workDir = mkOption {
      type = types.path;
      default = "/var/lib/keycloak";
      description = ''
        Working directory for Keycloak.
      '';
    };

    configDir = mkOption {
      type = types.path;
      default = "/etc/keycloak";
      description = ''
        Configuration directory for Keycloak.
      '';
    };

    logDir = mkOption {
      type = types.path;
      default = "/var/log/keycloak";
      description = ''
        Working directory for Keycloak.
      '';
    };
  };

  config = mkIf cfg.enable {
    users.groups.keycloak = {};
    users.users.keycloak = {
      description = "Keycloak service user";
      group = "keycloak";
      extraGroups = cfg.groups;
      home = cfg.workDir;
      isSystemUser = true;
    };

    systemd.services.keycloak = {
      description = "Keycloak Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "networking.target" ];
      serviceConfig = {
        WorkingDirectory = cfg.workDir;
        LogsDirectory = "keycloak";
        StateDirectory = "keycloak";
        ConfigurationDirectory = "keycloak";
        ExecStart = "${pkgs.keycloak}/bin/standalone.sh --read-only-server-config=${pkgs.keycloak}/standalone/configuration/standalone.xml -Djboss.server.data.dir=${cfg.workDir} -Djboss.server.config.dir=${cfg.configDir} -Djboss.server.log.dir=${cfg.logDir} -Djboss.server.temp.dir=/tmp";
        Restart = "always";
        User = "keycloak";
        PrivateTmp = true;
      };
    };
  };
}
