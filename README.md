# Digilent WaveForms for NixOS

Nix flake packaging [Digilent WaveForms](https://digilent.com/reference/software/waveforms/waveforms-3/start)
and the [Adept 2 runtime](https://digilent.com/reference/software/adept/start) for
`x86_64-linux` and `aarch64-linux`.

The upstream `.deb` packages are downloaded from Digilent at build time and are not
redistributed here. Both packages are unfree; the flake enables `allowUnfree` on its
own nixpkgs import.

## NixOS module

Add the exported `nixosModules.default` module to your system configuration, then enable with `programs.waveforms.enable = true`.
If you're accessing the machine headless, add your user to the `plugdev` group.

Importing the module does nothing until `programs.waveforms.enable` is set.
`programs.waveforms.package` can replace the package; the udev rules and config come from its `digilent-adept-runtime` passthru.

When enabled, the module:

- Installs `waveforms` (and `dwfcmd`)
- Adds udev rules that give the logged-in user (`uaccess`) and `plugdev` group access to Digilent devices instead of upstream's world-writable `MODE="666"`
- Writes `/etc/digilent-adept.conf`, used by `libdwf` when loaded from your own programs
- Links `/usr/share/digilent/waveforms` to the package. `libdwf` has no setting for its firmware directory, and looks in `../share/digilent/waveforms` relative to the running executable, then in `/opt/digilent/waveforms`, `/usr/local/digilent/waveforms`, `/usr/local/share/digilent/waveforms` and `/usr/share/digilent/waveforms`. The GUI finds it next to itself, but a Python script (where the executable is `python`) needs this link.

### Example

```nix
{
  inputs.waveforms.url = "github:RandomSpaceship/digilent-waveforms";

  outputs = { nixpkgs, waveforms, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        waveforms.nixosModules.default
        {
          programs.waveforms.enable = true;
          # Only needed for access outside a local desktop session (e.g. over SSH):
          users.users.me.extraGroups = [ "plugdev" ];
        }
      ];
    };
  };
}
```


## Without the module

If you just want to get it up and running:

```sh
nix run github:RandomSpaceship/digilent-waveforms                 # run WaveForms
nix run github:RandomSpaceship/digilent-waveforms#setup-udev      # udev rules until next reboot
nix run github:RandomSpaceship/digilent-waveforms#setup-udev -- --remove # clean up udev rules
```

`setup-udev` puts the rules in `/run/udev/rules.d` (cleared on reboot) and re-triggers attached devices.
Using `libdwf` from Python without the module also needs
`DIGILENT_ADEPT_CONF` pointing at the runtime's `etc/digilent-adept.conf`, and a link to the package's `share/digilent/waveforms` at one of the paths above.

An overlay is also provided as `overlays.default` (`waveforms`, `digilent-adept-runtime`).
Applied to your own nixpkgs, it needs `allowUnfree` (or an `allowUnfreePredicate` for both packages) there.

## If the download fails

`files.digilent.com` blocks curl's default user agent, so the fetch sends a browser one.
If that stops working, download the `.deb` in a browser and add it to the store under its original name.
The hash in [sources.nix](sources.nix) then matches and Nix skips the download:

```sh
nix-prefetch-url file://$PWD/digilent.waveforms_3.25.1_amd64.deb
nix-prefetch-url file://$PWD/digilent.adept.runtime_2.30.1_amd64.deb
```

## Updating

Bump the `version` in [sources.nix](sources.nix) (the URLs and file names are built
from it) and set each of its hashes to `""`. Then run

```sh
nix build --keep-going .#debs.{x86_64,aarch64}-linux.{waveforms,digilent-adept-runtime}
```

It only downloads, so it works on any machine, and fails with the correct hash
(`got: sha256-…`) for each file; paste them in and run it again.
`nix store prefetch-file` and plain `curl` won't work here, because Digilent rejects
their user agent (HTTP 403). For a file you downloaded in a browser, `nix hash file <file>`
gives the same hash.

CI ([check.yml](.github/workflows/check.yml)) builds every package and runs
`nix flake check` on x86_64 and aarch64 runners: the package builds, `libdwf` loading
from Python, the module's configuration, and formatting (`nix fmt`).

## Prior work

- [liff/waveforms-flake](https://github.com/liff/waveforms-flake): another flake for
  WaveForms. Its Adept package ships only the libraries, without the device firmware
  data or the `dftdrvdtch` helper its udev rule calls, and it doesn't set up `libdwf`
  for use from your own programs.
- [WaveForms on NixOS](https://forum.digilent.com/topic/33090-waveforms-on-nixos/)
  (Digilent forum): earlier packaging that runs WaveForms in an FHS environment, and
  the source of the manual prefetch workaround.

## License

The Nix code in this repository is under the [MIT license](LICENSE.md). WaveForms and
the Adept runtime are proprietary software by Digilent under their own license terms;
they are downloaded from Digilent at build time, not included or redistributed here.
