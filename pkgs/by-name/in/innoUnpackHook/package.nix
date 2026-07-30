{
  lib,
  makeSetupHook,
  innoextract,
}:

makeSetupHook {
  name = "inno-unpack-hook";
  propagatedBuildInputs = [
    innoextract
  ];
  meta.license = lib.licenses.mit;
} ./inno-unpack.sh
