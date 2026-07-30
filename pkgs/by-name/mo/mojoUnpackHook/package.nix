{
  lib,
  makeSetupHook,
  unzip
}:

makeSetupHook {
  name = "mojo-unpack-hook";
  propagatedBuildInputs = [
    unzip
  ];
  meta.license = lib.licenses.mit;
} ./mojo-unpack.sh
