# Upstream .deb packages, fetched from Digilent at build time (not redistributed).
# To update, bump `version` and set every hash to ""; the build then fails with
# the correct hash for each file.
#
# `name` is the upstream file name, so a .deb downloaded in a browser can be
# added to the store by hand and matches the fetch (see the README):
#   nix-prefetch-url file://$PWD/digilent.waveforms_3.25.1_amd64.deb
let
  debArch = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };

  # `urlDir` is the directory on files.digilent.com, which also has the version
  # in it. Returns { name, url, hash } per system.
  mkSource =
    {
      debName,
      urlDir,
      version,
      hashes,
    }:
    {
      inherit version;
      platforms = builtins.attrNames hashes;
      src =
        system:
        let
          name = "${debName}_${version}_${debArch.${system}}.deb";
        in
        {
          inherit name;
          url = "https://files.digilent.com/Software/${urlDir}/${version}/${name}";
          hash = hashes.${system};
        };
    };
in
{
  digilent-adept-runtime = mkSource {
    debName = "digilent.adept.runtime";
    urlDir = "Adept2%20Runtime";
    version = "2.30.1";
    hashes = {
      x86_64-linux = "sha256-5eUdJkDC/zTvO0NvO983g4EgsVFg1z37q4LpB3O2s3I=";
      aarch64-linux = "sha256-jNRg4/vK+4ttctztRO3Mm6aOpy/+a7pJ4N+q1xugc5I=";
    };
  };

  waveforms = mkSource {
    debName = "digilent.waveforms";
    urlDir = "Waveforms";
    version = "3.25.1";
    hashes = {
      x86_64-linux = "sha256-0peaq3JskgKkihxdKzFFMVExccC2L6Lyou3NKSAnJ9M=";
      aarch64-linux = "sha256-FP/EUD9znoepV+82P5lPVE5Jt33sxOPvS7ysODLIA0U=";
    };
  };
}
