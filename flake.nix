{
  description = "Digilent WaveForms (repackaged from the upstream .deb)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
              overlays = [ self.overlays.default ];
            }
          )
        );
    in
    {
      # Applied to your own nixpkgs, this needs `allowUnfree` there.
      overlays.default = final: prev: {
        digilent-adept-runtime = final.callPackage ./digilent-adept-runtime.nix { };
        waveforms = final.callPackage ./waveforms.nix { };
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      packages = forAllSystems (pkgs: {
        inherit (pkgs) digilent-adept-runtime waveforms;
        setup-udev = pkgs.callPackage ./setup-udev.nix { };
        default = pkgs.waveforms;
      });

      # Every upstream .deb for every supported system, fetched with this
      # system's tools (same store paths as the packages' `src`), e.g. to get the
      # hashes after a version bump:
      #   nix build .#debs.aarch64-linux.waveforms
      legacyPackages = forAllSystems (
        pkgs:
        let
          fetchDigilent = pkgs.callPackage ./fetch-digilent.nix { };
        in
        {
          debs = nixpkgs.lib.genAttrs systems (
            system: builtins.mapAttrs (_: source: fetchDigilent (source.src system)) (import ./sources.nix)
          );
        }
      );

      apps = forAllSystems (
        pkgs:
        let
          p = self.packages.${pkgs.stdenv.hostPlatform.system};
        in
        {
          default = {
            type = "app";
            program = "${p.waveforms}/bin/waveforms";
          };
          # Temporary (until reboot) udev rules, for when the NixOS module isn't used:
          #   nix run .#setup-udev               install
          #   nix run .#setup-udev -- --remove   remove
          setup-udev = {
            type = "app";
            program = "${p.setup-udev}/bin/digilent-setup-udev";
          };
        }
      );

      checks = forAllSystems (
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          p = self.packages.${system};

          # A minimal system with the module enabled, evaluated (not built).
          nixos =
            (nixpkgs.lib.nixosSystem {
              modules = [
                self.nixosModules.default
                {
                  nixpkgs.hostPlatform = system;
                  programs.waveforms.enable = true;
                  boot.loader.grub.enable = false;
                  fileSystems."/" = {
                    device = "none";
                    fsType = "tmpfs";
                  };
                  system.stateVersion = "26.05";
                }
              ];
            }).config;
        in
        {
          inherit (p) digilent-adept-runtime waveforms setup-udev;

          # libdwf loads (all its Adept libraries resolve) and reads the
          # runtime config, as it would from a user's Python script.
          libdwf =
            pkgs.runCommand "check-libdwf"
              {
                nativeBuildInputs = [ pkgs.python3 ];
                DIGILENT_ADEPT_CONF = "${p.digilent-adept-runtime}/etc/digilent-adept.conf";
              }
              ''
                python3 - <<'EOF'
                import ctypes
                dwf = ctypes.cdll.LoadLibrary("${p.waveforms}/lib/libdwf.so")
                version = ctypes.create_string_buffer(32)
                assert dwf.FDwfGetVersion(version), "FDwfGetVersion failed"
                assert version.value.decode() == "${p.waveforms.version}", version.value
                print("libdwf", version.value.decode())
                EOF
                touch $out
              '';

          module =
            assert nixos.environment.etc ? "digilent-adept.conf";
            assert nixos.users.groups ? plugdev;
            assert builtins.elem p.digilent-adept-runtime nixos.services.udev.packages;
            assert builtins.elem
              "L+ /usr/share/digilent/waveforms - - - - ${p.waveforms}/share/digilent/waveforms"
              nixos.systemd.tmpfiles.rules;
            pkgs.writeText "check-module" "ok";

          format = pkgs.runCommand "check-format" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            nixfmt --check ${./.}/*.nix
            touch $out
          '';
        }
      );

      # programs.waveforms.enable installs the package, udev rules (USB access
      # for the logged-in user and the plugdev group) and
      # /etc/digilent-adept.conf, and links the WaveForms data to
      # /usr/share/digilent/waveforms, the only place libdwf looks for device
      # firmware when loaded from your own programs (e.g. Python).
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.waveforms;
          inherit (cfg.package) digilent-adept-runtime;
        in
        {
          options.programs.waveforms = {
            enable = lib.mkEnableOption "Digilent WaveForms, with udev rules and system config for its devices";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.waveforms;
              defaultText = lib.literalExpression "waveforms.packages.\${pkgs.stdenv.hostPlatform.system}.waveforms";
              description = "The WaveForms package. Its `digilent-adept-runtime` passthru supplies the udev rules and config.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
            services.udev.packages = [ digilent-adept-runtime ];
            users.groups.plugdev = { };
            environment.etc."digilent-adept.conf".source = "${digilent-adept-runtime}/etc/digilent-adept.conf";
            systemd.tmpfiles.rules = [
              "d /usr/share 0755 root root -"
              "d /usr/share/digilent 0755 root root -"
              "L+ /usr/share/digilent/waveforms - - - - ${cfg.package}/share/digilent/waveforms"
            ];
          };
        };
    };
}
