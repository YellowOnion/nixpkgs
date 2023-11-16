{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, libuuid
, libsodium
, keyutils
, liburcu
, zlib
, libaio
, zstd
, lz4
, attr
, udev
, nixosTests
, fuse3
, cargo
, rustc
, rustPlatform
, makeWrapper
, fuseSupport ? false
}:
let
  rev = "fbe4d8ca847f1e16195642630776cbd85e7f941";
  src = fetchFromGitHub {
    owner = "koverstreet";
    repo = "bcachefs-tools";
    inherit rev;
    hash = "sha256-8FNdvvickRioJ8VOfnq90Kdo8y8Nq9zLTVHHX9pIc1Y=";
  };

in
stdenv.mkDerivation {
  inherit src;
  pname = "bcachefs-tools";
  version = "unstable-2023-11-17";


  nativeBuildInputs = [
    pkg-config
    cargo
    rustc
    rustPlatform.cargoSetupHook
    rustPlatform.bindgenHook
    makeWrapper
  ];

  cargoRoot = "rust-src";
  cargoDeps = rustPlatform.importCargoLock {
    lockFile = "${src}/rust-src/Cargo.lock";
    outputHashes = {
      "bindgen-0.64.0" = "sha256-GNG8as33HLRYJGYe0nw6qBzq86aHiGonyynEM7gaEE4=";
    };
  };

  buildInputs = [
    libaio
    keyutils
    lz4

    libsodium
    liburcu
    libuuid
    zstd
    zlib
    attr
    udev
  ] ++ lib.optional fuseSupport fuse3;

  doCheck = false; # needs bcachefs module loaded on builder
  checkFlags = [ "BCACHEFS_TEST_USE_VALGRIND=no" ];

  makeFlags = [
    "PREFIX=${placeholder "out"}"
    "VERSION=${lib.strings.substring 0 7 rev}"
    "INITRAMFS_DIR=${placeholder "out"}/etc/initramfs-tools"
  ];

  preCheck = lib.optionalString (!fuseSupport) ''
    rm tests/test_fuse.py
  '';

  passthru.tests = {
    smoke-test = nixosTests.bcachefs;
    inherit (nixosTests.installer) bcachefsSimple bcachefsEncrypted bcachefsMulti;
  };

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Tool for managing bcachefs filesystems";
    homepage = "https://bcachefs.org/";
    license = licenses.gpl2;
    maintainers = with maintainers; [ davidak Madouura ];
    platforms = platforms.linux;
  };
}
