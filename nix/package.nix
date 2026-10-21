{ lib
, stdenvNoCC
, makeWrapper
, bash
, coreutils
, findutils
, gawk
, gnugrep
, gnused
, python3
  # Fixed base configuration baked into the store; override to change it.
, configFile ? ../config.yml
}:

let
  python = python3.withPackages (ps: [ ps.pyyaml ps.bibtexparser ps.segno ps.opencv4 ]);
  runtimeInputs = [
    bash
    coreutils
    findutils
    gawk
    gnugrep
    gnused
    python
  ];
in
stdenvNoCC.mkDerivation {
  pname = "linto";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ../.;
    filter = path: type:
      !(builtins.elem (builtins.baseNameOf (toString path)) [ ".git" ".zed" "tests" ]);
  };

  nativeBuildInputs = [ makeWrapper ] ++ runtimeInputs;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/linto" "$out/bin"
    cp -R . "$out/lib/linto"
    chmod u+w "$out/lib/linto/config.yml"
    cp ${configFile} "$out/lib/linto/config.yml"
    install -Dm444 ${configFile} "$out/etc/linto/config.yml"
    # addgroup, rmgroup, refresh and addman are development scripts, and
    # setup, mdsetup and venv prepare non-Nix systems; Nix provides PATH and completions and
    # the store tree is read-only, so none of them are shipped.
    rm -f \
      "$out/lib/linto/groups/linto/addgroup.sh" \
      "$out/lib/linto/groups/linto/rmgroup.sh" \
      "$out/lib/linto/groups/linto/refresh.sh" \
      "$out/lib/linto/groups/linto/addman.sh" \
      "$out/lib/linto/groups/linto/setup.sh" \
      "$out/lib/linto/groups/linto/mdsetup.sh" \
      "$out/lib/linto/groups/linto/venv.sh" \
      "$out/lib/linto/bin/linto-linto-addgroup" \
      "$out/lib/linto/bin/linto-linto-rmgroup" \
      "$out/lib/linto/bin/linto-linto-refresh" \
      "$out/lib/linto/bin/linto-linto-addman" \
      "$out/lib/linto/bin/linto-linto-setup" \
      "$out/lib/linto/bin/linto-linto-mdsetup" \
      "$out/lib/linto/bin/linto-linto-venv" \
      "$out/lib/linto/bin/linto-beta-addman"
    patchShebangs "$out/lib/linto"

    mv "$out/lib/linto/bin/linto" "$out/lib/linto/bin/linto-unwrapped"
    makeWrapper "$out/lib/linto/bin/linto-unwrapped" "$out/lib/linto/bin/linto" \
      --prefix PATH : "${lib.makeBinPath runtimeInputs}"
    ln -s "$out/lib/linto/bin/linto" "$out/bin/linto"

    for executable in "$out/lib/linto/bin"/linto-*; do
      [ -f "$executable" ] || continue
      ln -s "$executable" "$out/bin/''${executable##*/}"
    done

    mkdir -p \
      "$out/share/bash-completion/completions" \
      "$out/share/fish/vendor_completions.d" \
      "$out/share/zsh/site-functions"
    ln -s "$out/lib/linto/completions/linto.bash" \
      "$out/share/bash-completion/completions/linto"
    ln -s "$out/lib/linto/completions/linto.fish" \
      "$out/share/fish/vendor_completions.d/linto.fish"
    ln -s "$out/lib/linto/completions/_linto" \
      "$out/share/zsh/site-functions/_linto"

    runHook postInstall
  '';

  meta = {
    description = "Local command-line toolbox for bibliography, Quarto, text, and shell utilities";
    mainProgram = "linto";
    platforms = lib.platforms.linux;
  };
}
