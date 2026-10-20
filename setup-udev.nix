{ writeShellApplication, digilent-adept-runtime }:

# One-off alternative to the NixOS module: installs the Digilent udev rules
# into /run/udev/rules.d (tmpfs, so they disappear on reboot) and re-triggers
# any attached devices. Run with --remove to undo before rebooting.
writeShellApplication {
  name = "digilent-setup-udev";
  text = ''
    rules=${digilent-adept-runtime}/lib/udev/rules.d/52-digilent-usb.rules
    dest=/run/udev/rules.d/52-digilent-usb.rules

    if [ "$(id -u)" -ne 0 ]; then
      exec sudo "$0" "$@"
    fi

    case "''${1:-}" in
      --remove)
        rm -f "$dest"
        echo "Removed $dest"
        ;;
      "")
        mkdir -p /run/udev/rules.d
        install -m 0644 "$rules" "$dest"
        echo "Installed $dest"
        ;;
      *)
        echo "usage: $(basename "$0") [--remove]" >&2
        exit 1
        ;;
    esac

    udevadm control --reload-rules
    for vendor in 1443 0403; do
      udevadm trigger --action=add --subsystem-match=usb --attr-match=idVendor="$vendor"
    done
    udevadm settle
  '';
}
