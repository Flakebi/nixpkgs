# adapted from upstream
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.noctalia-greeter;
  format = pkgs.formats.toml { };

  inherit (lib)
    getExe'
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    ;

  inherit (lib.types)
    str
    ;
in
{
  options.programs.noctalia-greeter = {
    enable = mkEnableOption "Noctalia Greeter, Minimal login greeter for greetd.";

    package = mkPackageOption pkgs "noctalia-greeter" { };

    greeter-args = mkOption {
      description = "Arguments to add to the noctalia-greeter-session invocation.";
      type = str;
      default = "";
    };

    settings = mkOption {
      description = "Settings for noctalia-greeter written to greeter.toml.";
      inherit (format) type;
      default = { };
      example = literalExpression ''
        {
          cursor = {
            theme = "Adwaita";
            size = 24;
          };
          keyboard = {
            layout = "us";
          };
        }
      '';
    };
  };

  config =
    let
      user = config.services.greetd.settings.default_session.user;
      group =
        if config.users.users.${user}.group != "" then config.users.users.${user}.group else "greeter";
    in
    mkIf cfg.enable {
      assertions = [
        {
          assertion = (config.users.users.${user} or { }) != { };
          message = "noctalia-greeter: user ${user} does not exist. Please create it before referencing it.";
        }
      ];

      environment.systemPackages = [ cfg.package ];

      systemd.tmpfiles.settings."10-noctalia-greeter" = {
        "/var/lib/noctalia-greeter".d = {
          inherit user group;
          mode = "0750";
        };

        "/var/lib/noctalia-greeter/greeter.toml".C = {
          argument = "${format.generate "greeter.toml" cfg.settings}";
          inherit user group;
          mode = "0644";
        };
      };

      services.greetd = {
        enable = mkDefault true;
        settings.default_session.command = mkDefault "${getExe' cfg.package "noctalia-greeter-session"} -- ${cfg.greeter-args}";
      };

      services.accounts-daemon.enable = mkDefault true;
    };

  meta.maintainers = with lib.maintainers; [ dtomvan ];
}
