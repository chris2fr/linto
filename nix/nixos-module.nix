{ config, lib, pkgs, ... }:

let
  cfg = config.programs.linto;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options.programs.linto = {
    enable = lib.mkEnableOption "Linto command-line tools";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      description = "The Linto package to install.";
    };

    settings = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      description = ''
        System-wide Linto configuration, written to /etc/linto/linto.yml.
        User configuration takes precedence over these settings.
      '';
      example = {
        groups.quarto.configdata.extension = "chris2fr/quarto";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    environment.etc = lib.mkIf (cfg.settings != { }) {
      "linto/linto.yml".source = yamlFormat.generate "linto.yml" cfg.settings;
    };
  };
}
