{ lib
, stdenv
, fetchpatch
, kernel
, buildLinux
, commitDate ? "2023-11-17"
# bcachefs-tools stores the expected-revision in:
#   https://evilpiepirate.org/git/bcachefs-tools.git/tree/.bcachefs_revision
# but this does not means that it'll be the latest-compatible revision
, currentCommit ? "938f680845d1be28979e23aee972dba010c464ba"
, diffHash ? "sha256-v3jFBe6vgS/+A+0C2DFDj2qparY2lltANxJ9xVhSVAk="
, kernelPatches # must always be defined in bcachefs' all-packages.nix entry because it's also a top-level attribute supplied by callPackage
, argsOverride ? {}
, usePatch ? false
, fetchFromGitHub
, ...
} @ args:
# NOTE: bcachefs-tools should be updated simultaneously to preserve compatibility
let commonArgs = kernel: ({
  argsOverride = {
    version = "${kernel.version}-bcachefs-unstable-${commitDate}";
    modDirVersion = kernel.modDirVersion;

    extraMeta = {
      homepage = "https://bcachefs.org/";
      branch = "master";
      maintainers = with lib.maintainers; [ davidak Madouura pedrohlc raitobezarius YellowOnion ];
    };
  };

  kernelPatches = kernelPatches;
  structuredExtraConfig = with lib.kernel; {
    BCACHEFS_FS = option yes;
    BCACHEFS_QUOTA = option yes;
    BCACHEFS_POSIX_ACL = option yes;
    # useful for bug reports
    FTRACE = option yes;
  };

});
in
(if usePatch then kernel.override ((commonArgs kernel) // {
  kernelPatches = [ {
      name = "bcachefs-${currentCommit}";
      patch = ./bcachefs.patch;
    } ] ++ kernelPatches;
})
 else
  buildLinux ( let
    args = (commonArgs { version = "6.6.0"; modDirVersion = "6.6.0"; });
  in
    args // {
      src = fetchFromGitHub {
        owner = "koverstreet";
        repo = "bcachefs";
        rev = currentCommit;
        hash = "sha256-bfXqVHwuaa9t711ec5JCIMY1eLYP2ECii/vd1y8LYiA=";
      };
    } // args.argsOverride or { })
)
