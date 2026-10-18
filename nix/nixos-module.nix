{ config, lib, pkgs, ... }:

let
  cfg = config.programs.linto;
  yamlFormat = pkgs.formats.yaml { };

  # Optional Markdown viewers for `linto help`; each maps to a nixpkgs package.
  viewerPackages = {
    md-tui = pkgs.md-tui;
    inlyne = pkgs.inlyne;
    mdcat = pkgs.mdcat;
    mandown = pkgs.mandown;
    glow = pkgs.glow;
    frogmouth = pkgs.frogmouth;
    bat = pkgs.bat;
    mdfried = pkgs.mdfried;
  };

  # Viewer preference list, in the order given, falling back to plain cat.
  viewerSettings = lib.optionalAttrs (cfg.markdownViewers != [ ]) {
    configdata.markdown-viewer = cfg.markdownViewers ++ [ "cat" ];
  };
  finalSettings = lib.recursiveUpdate viewerSettings cfg.settings;
in
{
  options.programs.linto = {
    enable = lib.mkEnableOption "Linto command-line tools";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      description = "The Linto package to install.";
    };

    markdownViewers = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (builtins.attrNames viewerPackages));
      default = [ ];
      example = [ "mdcat" "glow" ];
      description = ''
        Optional Markdown viewers for `linto help`, in order of preference.
        The packages are installed and `configdata.markdown-viewer` is set
        accordingly (with `cat` as the final fallback). `mandown` also pulls in
        `groff`. Leave empty to display guide pages with `cat`.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.quarto pkgs.zed-editor pkgs.xdg-utils ]";
      description = ''
        Optional tools used by some Linto commands (for example Quarto for the
        `quarto` group, Zed for `launch zed`, `xdg-open` for opening output).
        They are installed system-wide alongside Linto.
      '';
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
    environment.systemPackages =
      [ cfg.package ]
      ++ map (name: viewerPackages.${name}) cfg.markdownViewers
      ++ lib.optional (builtins.elem "mandown" cfg.markdownViewers) pkgs.groff
      ++ cfg.extraPackages;

    environment.etc = lib.mkIf (finalSettings != { }) {
      "linto/linto.yml".source = yamlFormat.generate "linto.yml" finalSettings;
    };
  };
}
