{ lib, appimageTools, requireFile, runCommand, python3, patchelf, glibc }:
let
  pname = "elyx";
  version = "0.0.1-preview.16889.g86cc7388a1";
  archive = requireFile ((import ./archive-source.nix) // {
    message = "Import your private Elyx archive first: ./import-archive.sh /path/to/any-name.tar.gz";
  });
  src = runCommand "${pname}-${version}.AppImage" {
    nativeBuildInputs = [ python3 ];
  } ''
    python3 - "${archive}" "$out" <<'PYTHON'
    import os
    import shutil
    import sys
    import tarfile

    with tarfile.open(sys.argv[1], "r:gz") as archive:
        images = [m for m in archive.getmembers() if m.isfile() and m.name.endswith(".AppImage")]
        if len(images) != 1:
            raise SystemExit("Expected exactly one regular .AppImage file in the archive")
        with archive.extractfile(images[0]) as source, open(sys.argv[2], "wb") as target:
            shutil.copyfileobj(source, target)
    os.chmod(sys.argv[2], 0o755)
    PYTHON
  '';
  appimageContents = appimageTools.extract {
    inherit pname version src;
    postExtract = ''
      chmod u+w "$out/resources/app.asar"
      ${python3}/bin/python3 ${./patch-installer.py} "$out/resources/app.asar"
      for executable in elyx elyx-daemon; do
        chmod u+w "$out/resources/bin/$executable"
        ${patchelf}/bin/patchelf \
          --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 \
          --force-rpath --add-rpath ${glibc}/lib \
          "$out/resources/bin/$executable"
      done
    '';
  };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  passthru.unwrapped = appimageContents;

  extraPkgs = pkgs: [ pkgs.libxkbfile ];

  # Electron does not use SDL; omit the game/audio stack from the generic
  # AppImage environment (including SDL_mixer's large MIDI sound bank).
  multiPkgs = pkgs: lib.subtractLists
    (with pkgs; [ SDL2 SDL2_image SDL2_mixer SDL2_ttf ])
    (appimageTools.defaultFhsEnvArgs.multiPkgs pkgs);

  extraInstallCommands = ''
    mv $out/bin/elyx $out/bin/elyx-preview
    ln -s ${appimageContents}/resources/bin/elyx $out/bin/elyx
    install -Dm644 ${appimageContents}/elyx.desktop $out/share/applications/elyx.desktop
    substituteInPlace $out/share/applications/elyx.desktop \
      --replace-fail 'Exec=AppRun %U' "Exec=$out/bin/elyx-preview %U"
    install -Dm644 ${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/elyx.png \
      $out/share/icons/hicolor/1024x1024/apps/elyx.png
  '';

  meta = {
    description = "A design tool for creating production-ready interfaces";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "elyx-preview";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
