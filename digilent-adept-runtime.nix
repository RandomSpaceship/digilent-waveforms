{
  lib,
  stdenv,
  callPackage,
  dpkg,
  autoPatchelfHook,
  avahi,
  libusb1,
  openssl,
}:

let
  sources = (import ./sources.nix).digilent-adept-runtime;
  fetchDigilent = callPackage ./fetch-digilent.nix { };
in
stdenv.mkDerivation {
  pname = "digilent-adept-runtime";
  inherit (sources) version;

  src = fetchDigilent (sources.src stdenv.hostPlatform.system);

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    avahi
    libusb1
    openssl
  ];

  # libdftd2xx dlopen()s libftd2xx.so, which sits next to it.
  appendRunpaths = [ "${placeholder "out"}/lib" ];

  unpackPhase = ''
    runHook preUnpack
    dpkg -x $src root
    runHook postUnpack
  '';

  # Upstream's rules make every Digilent device world-writable (MODE:="666").
  # Instead grant access to the logged-in seat user (uaccess) and to the
  # plugdev group (for SSH/headless use; created by the NixOS module).
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/udev/rules.d $out/etc $out/share/doc
    cp -P root/usr/lib/digilent/adept/* $out/lib/
    cp root/usr/lib/udev/dftdrvdtch $out/lib/udev/
    cp -r root/usr/share/digilent $out/share/
    cp -r root/usr/share/doc/digilent.adept.runtime $out/share/doc/

    sed -e "s|=/usr/share|=$out/share|" root/etc/digilent-adept.conf > $out/etc/digilent-adept.conf

    cat > $out/lib/udev/rules.d/52-digilent-usb.rules <<EOF
    SUBSYSTEM=="usb", ATTR{idVendor}=="1443", GROUP="plugdev", MODE="0660", TAG+="uaccess"
    SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="0403", ATTR{manufacturer}=="Digilent", GROUP="plugdev", MODE="0660", TAG+="uaccess", RUN+="$out/lib/udev/dftdrvdtch %s{busnum} %s{devnum}"
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Digilent Adept 2 runtime";
    homepage = "https://digilent.com/reference/software/adept/start";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    inherit (sources) platforms;
  };
}
