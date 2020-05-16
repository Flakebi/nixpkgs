{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ackee;

in
{
  options.services.ackee = {
    enable = mkEnableOption "the Ackee analytics tool";

    groups = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Groups to which the ackee user should be added.
      '';
    };

    db = mkOption {
      type = types.str;
      default = "mongodb://localhost:27017/ackee";
      description = ''
        The database
      '';
    };

    username = mkOption {
      type = types.str;
      default = "ackee";
      description = ''
        The database username
      '';
    };

    password = mkOption {
      type = types.str;
      example = "ackee";
      description = ''
        The database password
      '';
    };
  };

  config = mkIf cfg.enable {
    users.groups.ackee = {};
    users.users.ackee = {
      description = "Ackee service user";
      group = "ackee";
      extraGroups = cfg.groups;
      isSystemUser = true;
    };

    systemd.services.ackee = {
      description = "Ackee Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "networking.target" "mongodb.service" ];
      serviceConfig = {
        WorkingDirectory = "${pkgs.mymaster.ackee}/libexec/ackee/deps/ackee/node_modules";
        ExecStart = "${pkgs.mymaster.ackee}/bin/ackee";
        Environment = [
          "ACKEE_MONGODB=${cfg.db}"
          "ACKEE_USERNAME=${cfg.username}"
          "ACKEE_PASSWORD=${cfg.password}"
          "NODE_ENV=production"
        ];
        Restart = "always";
        User = "ackee";
        PrivateTmp = true;
      };
    };
  };
}
