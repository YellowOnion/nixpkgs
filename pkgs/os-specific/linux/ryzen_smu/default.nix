{ lib, stdenv, kernel, fetchFromGitLab }:

stdenv.mkDerivation {
  pname  = "ryzen_smu";
  version = "unstable-2023-06-16";

  src = fetchFromGitLab {
    owner = "leogx9r";
    repo = "ryzen_smu";
    rev = "e61177d0ddaebfaeca52094b20a2289287a0838b";
    sha256 = "sha256-n4uWikGg0Kcki/TvV4BiRO3/VE5M6/KopPncj5RQFAQ=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  buildPhase = ''
   make "KERNEL_BUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
   cd ./userspace
   make
   cd ..
   '';

  installPhase = ''
    install -D ryzen_smu.ko -t "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/hwmon/"
    mkdir -p $out/bin
    install -D userspace/monitor_cpu "$out/bin/"
  '';

  meta = with lib; {
    inherit (src.meta) homeage;
    description = "A Linux kernel driver that exposes access to the SMU (System Management Unit) for certain AMD Ryzen Processors.";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ YellowOnion ];
    platforms = [ "x86_64-linux" ];
  };
}
