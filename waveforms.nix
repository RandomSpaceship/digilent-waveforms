{
  lib,
  stdenv,
  callPackage,
  dpkg,
  autoPatchelfHook,
  qt6,
  libGL,
  pipewire,
  digilent-adept-runtime,
  runtimeShell,
  xdg-utils,
}:

let
  sources = (import ./sources.nix).waveforms;
  fetchDigilent = callPackage ./fetch-digilent.nix { };
in
stdenv.mkDerivation {
  pname = "waveforms";
  inherit (sources) version;

  src = fetchDigilent (sources.src stdenv.hostPlatform.system);

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libGL
    digilent-adept-runtime
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qtserialport
    qt6.qtwayland
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec
    cp -r usr/{bin,lib,include,share} $out/
    rm -rf $out/share/lintian

    # "Open samples folder" etc. hand a hard-coded file:///usr/share/digilent/
    # URL to xdg-open; rewrite it to the store.
    cat > $out/libexec/xdg-open <<EOF
    #!${runtimeShell}
    args=()
    for a in "\$@"; do
      case "\$a" in
        file:///usr/share/digilent/*) a="file://$out/share/digilent/\''${a#file:///usr/share/digilent/}" ;;
      esac
      args+=("\$a")
    done
    exec ${xdg-utils}/bin/xdg-open "\''${args[@]}"
    EOF
    chmod +x $out/libexec/xdg-open

    substituteInPlace $out/share/applications/digilent.waveforms.desktop \
      --replace-fail /usr/bin/waveforms $out/bin/waveforms \
      --replace-fail /usr/share $out/share

    runHook postInstall
  '';

  # Data files (docs, firmware) are found relative to the executable; the Adept
  # runtime is pointed at its store config instead of /etc/digilent-adept.conf.
  qtWrapperArgs = [
    "--prefix PATH : ${placeholder "out"}/libexec"
    # Qt Multimedia dlopen()s libpipewire for audio devices.
    "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pipewire ]}"
    "--set-default DIGILENT_ADEPT_CONF ${digilent-adept-runtime}/etc/digilent-adept.conf"
    "--set-default DIGILENT_DIR ${digilent-adept-runtime}/share/digilent"
    "--set-default DIGILENT_DATA_DIR ${digilent-adept-runtime}/share/digilent/adept/data"
  ];

  # The NixOS module installs this runtime's udev rules and config, so they
  # match whatever runtime the package was built against.
  passthru = { inherit digilent-adept-runtime; };

  meta = {
    description = "Digilent WaveForms application, runtime and SDK";
    homepage = "https://digilent.com/reference/software/waveforms/waveforms-3/start";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    inherit (sources) platforms;
    mainProgram = "waveforms";
  };
}
