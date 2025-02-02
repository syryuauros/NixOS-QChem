{ stdenv, lib, which, makeWrapper, gfortran, requireFile
, python3, blas, lapack
,  mpi ? null
} :

# Make sure to have a correct version of BLAS.
assert
  lib.asserts.assertMsg
  (blas.isILP64 || blas.passthru.implementation == "mkl")
  "A 64 bit integer implementation of BLAS is required.";

assert
  lib.asserts.assertMsg lapack.isILP64
  "A 64 bit integer implementation of LAPACK is required.";

let
  useMPI = mpi != null;
  mpiImplementation = if mpi.pname == "mvapich" then "mpich" else mpi.pname;

in stdenv.mkDerivation rec {
  pname = "cfour";
  version = "2.1";

  nativeBuildInputs = [ python3 makeWrapper ];

  buildInputs = [
    gfortran
    blas
    lapack
  ];

  propagatedBuildInputs = lib.optional useMPI mpi;

  src = requireFile {
    name = "cfour-public-v${version}.tar.bz2";
    sha256 = "d88c1d7ca360f12edeca012a01ab9da7ba4792ee43d85c178f92fbe83cbdcdc4";
    url = "http://www.cfour.de/";
  };

  postPatch = "patchShebangs ./config/mkdep90.py";

  preConfigure =
    let mpiConfig = lib.optionalString useMPI ''
          --enable-mpi=${mpiImplementation}
          --with-mpirun="${mpi}/bin/mpiexec -np \$CFOUR_NUM_CORES"
          --with-exenodes="${mpi}/bin/mpiexec -np \$CFOUR_NUM_CORES"
        '';
     in ''
       configureFlagsArray+=(
        ${mpiConfig}
        FCFLAGS="-fno-optimize-strlen -fno-stack-protector"
        CFLAGS="-fno-optimize-strlen -fno-stack-protector"
        CXXFLAGS="-fno-optimize-strlen -fno-stack-protector"
      )
    '';

  hardeningDisable = [ "format" ];

  postFixup = ''
    for exe in $out/bin/*; do
      wrapProgram $exe \
        --set-default CFOUR_NUM_CORES 1 \
        --prefix PATH : "${which}/bin"
    done
  '';

  passthru = { inherit mpi; };

  meta = with lib; {
    description = "Specialist coupled cluster software.";
    homepage = "http://slater.chemie.uni-mainz.de/cfour/index.php";
    license = licenses.unfree;
    mainProgram = "xcfour";
    platforms = platforms.linux;
  };
}
