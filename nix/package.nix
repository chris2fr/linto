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
}:

let
  python = python3.withPackages (ps: [ ps.pyyaml ps.bibtexparser ]);
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
