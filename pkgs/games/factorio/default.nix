{ lib
, alsa-lib
, factorio-utils
, fetchurl
, libGL
, libICE
, libSM
, libX11
, libXcursor
, libXext
, libXi
, libXinerama
, libXrandr
, libpulseaudio
, libxkbcommon
, makeDesktopItem
, makeWrapper
, releaseType
, stdenv
, wayland
, playerDataJson ? "/fpd.json"
, mods ? []
, mods-dat ? null
, versionsJson ? ./versions.json
, experimental ? false # true means to always use the latest branch
, ...
} @ args:

assert releaseType == "alpha"
  || releaseType == "headless"
  || releaseType == "demo";

let
  inherit (lib) importJSON;

  helpMsg = ''

    ===FETCH FAILED===
    Please ensure you have a player-data.json file accessable to nixbld.
    then build with --option extra-sandbox-paths /fpd.json=<location>
    or put it in configuration.nix with nix.settings.extra-sandbox-paths

    $ chmod go-rw ~/.factorio/player-data.json
    $ cp -p ~/.factorio/player-data.json /tmp/fpd.json
    $ setfacl -m g:nixbld:r ~/tmp/fpd.json
    $ nix-build '<nixpkgs>' -A factorio --option extra-sandbox-paths '/fpd.json=/tmp/fpd.json'
    $ rm /tmp/fpd.json

    Alternatively, instead of providing the player-data.json file, you may manually
    download the release through https://factorio.com/download , then add it to
    the store using e.g.:

      releaseType=alpha
      version=0.17.74
      nix-prefetch-url file://\''$HOME/Downloads/factorio_\''${releaseType}_x64_\''${version}.tar.xz --name factorio_\''${releaseType}_x64-\''${version}.tar.xz

    Note the ultimate "_" is replaced with "-" in the --name arg!
  '';

  desktopItem = makeDesktopItem {
    name = "factorio";
    desktopName = "Factorio";
    comment = "A game in which you build and maintain factories.";
    exec = "factorio";
    icon = "factorio";
    categories = [ "Game" ];
  };

  branch = if experimental then "experimental" else "stable";

  # NB `experimental` directs us to take the latest build, regardless of its branch;
  # hence the (stable, experimental) pairs may sometimes refer to the same distributable.
  versions = importJSON versionsJson;
  binDists = makeBinDists versions;

  actual = binDists.${stdenv.hostPlatform.system}.${releaseType}.${branch} or (throw "Factorio ${releaseType}-${branch} binaries for ${stdenv.hostPlatform.system} are not available for download.");

  makeBinDists = versions:
    let
      f = path: name: value:
        if builtins.isAttrs value then
          if value ? "name" then
            makeBinDist value
          else
            builtins.mapAttrs (f (path ++ [ name ])) value
        else
          throw "expected attrset at ${toString path} - got ${toString value}";
    in
    builtins.mapAttrs (f [ ]) versions;
  makeBinDist = { name, version, tarDirectory, url, sha256, needsAuth }: {
    inherit version tarDirectory;
    src =
      if !needsAuth then
        fetchurl { inherit name url sha256; }
      else
        factorio-utils.fetchFactorio playerDataJson {inherit name url sha256; }
         ;
  };

  configBaseCfg = ''
    use-system-read-write-data-directories=false
    [path]
    read-data=$out/share/factorio/data/
    [other]
    check_updates=false
  '';

  updateConfigSh = ''
    #! $SHELL
    # TODO make this more robust, use symlinks instead of regex?
    # why doesn't the game's dynamic system work?
    if [[ -e ~/.factorio/config.cfg ]]; then
      # Config file exists, but may have wrong path.
      # Try to edit it. I'm sure this is perfectly safe and will never go wrong.
      sed -i 's|^read-data=.*|read-data=$out/share/factorio/data/|' ~/.factorio/config.cfg
    else
      # Config file does not exist. Phew.
      install -D $out/share/factorio/config-base.cfg ~/.factorio/config.cfg
    fi
  '';

  base = with actual; {
    pname = "factorio-${releaseType}";
    inherit version src;

    preferLocalBuild = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/{bin,share/factorio}
      cp -a data $out/share/factorio
      cp -a bin/${tarDirectory}/factorio $out/bin/factorio
      patchelf \
        --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) \
        $out/bin/factorio
    '';

    # passthru.updateScript =
    # TODO figure out how to use the new auth system for this.

    meta = {
      description = "A game in which you build and maintain factories";
      longDescription = ''
        Factorio is a game in which you build and maintain factories.

        You will be mining resources, researching technologies, building
        infrastructure, automating production and fighting enemies. Use your
        imagination to design your factory, combine simple elements into
        ingenious structures, apply management skills to keep it working and
        finally protect it from the creatures who don't really like you.

        Factorio has been in development since spring of 2012, and reached
        version 1.0 in mid 2020.

        You can acquire up to date mods for nix at https://github.com/YellowOnion/factorio-mods-nix
      '';
      homepage = "https://www.factorio.com/";
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      license = lib.licenses.unfree;
      maintainers = with lib.maintainers; [ Baughn elitak erictapen priegger lukegb ];
      platforms = [ "x86_64-linux" ];
    };
  };

  releases = rec {
    headless = base;
    demo = base // {

      nativeBuildInputs = [ makeWrapper ];
      buildInputs = [ libpulseaudio ];

      libPath = lib.makeLibraryPath [
        alsa-lib
        libGL
        libICE
        libSM
        libX11
        libXcursor
        libXext
        libXi
        libXinerama
        libXrandr
        libpulseaudio
        libxkbcommon
        wayland
      ];

      installPhase = base.installPhase + ''
        wrapProgram $out/bin/factorio                                \
          --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:$libPath \
          --run "$out/share/factorio/update-config.sh"               \
          --argv0 ""                                                 \
          --add-flags "-c \$HOME/.factorio/config.cfg"               \
          # TODO / RFC
          # factorio needs write permissions to the mod directory to change settings.
          # the old version that used the nix store directly cannot work.
          # We can either, leave it up to factorio to manage mods as I have now.
          # Or add a section to update-config.sh that symlinks all mods in to ~/.factorio/mods

        install -m0644 <(cat << EOF
        ${configBaseCfg}
        EOF
        ) $out/share/factorio/config-base.cfg

        install -m0755 <(cat << EOF
        ${updateConfigSh}
        EOF
        ) $out/share/factorio/update-config.sh

        mkdir -p $out/share/icons/hicolor/{64x64,128x128}/apps
        cp -a data/core/graphics/factorio-icon.png $out/share/icons/hicolor/64x64/apps/factorio.png
        cp -a data/core/graphics/factorio-icon@2x.png $out/share/icons/hicolor/128x128/apps/factorio.png
        ln -s ${desktopItem}/share/applications $out/share/
      '';
    };
    alpha = demo // {

      installPhase = demo.installPhase + ''
        cp -a doc-html $out/share/factorio
      '';
    };
  };

in
stdenv.mkDerivation (releases.${releaseType})
