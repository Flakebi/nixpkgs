{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.prometheus.telegram-bot;
  settingsFormat = pkgs.formats.yaml {};
  configFile = settingsFormat.generate "prometheus-telegram-bot.yml" cfg.settings;
in
{
  options.services.prometheus.telegram-bot = {
    enable = mkEnableOption "Telegram bot for prometheus alerting";

    settings = mkOption {
      type = settingsFormat.type;
      default = {};

      description = ''
        Configuration for prometheus telegram bot, see
        <link xlink:href="https://github.com/inCaller/prometheus_bot#usage"/>
        for supported values.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.prometheus-telegram-bot = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.prometheus-telegram-bot}/bin/prometheus_bot --config ${configFile}";
        Restart = "on-failure";
        # TODO More security options
        DynamicUser = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        NoNewPrivileges = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        SystemCallFilter = [ "@system-service" ];
      };
    };
  };
}
