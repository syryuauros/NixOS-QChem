{ lib, stdenv, pkgs, fetchFromGitLab, fetchpatch, cmake, gfortran, perl
, blas, hdf5-full, python3, texlive
, armadillo, makeWrapper, fetchFromGitHub, chemps2, libwfa, libxc
} :

assert
  lib.asserts.assertMsg
  (blas.isILP64 || blas.passthru.implementation == "mkl")
  "A 64 bit integer BLAS implementation is required.";

assert
  lib.asserts.assertMsg
  (builtins.elem blas.passthru.implementation [ "openblas" "mkl" ])
  "OpenMolcas requires OpenBLAS or MKL.";

let
  version = "22.02-2022-02-10";
  gitLabRev = "f8df69cf87b241a15ebc82d72a8f9a031a385dd4";

  python = python3.withPackages (ps : with ps; [ six pyparsing ]);

in stdenv.mkDerivation {
  pname = "openmolcas";
  inherit version;

  src = fetchFromGitLab {
    owner = "Molcas";
    repo = "OpenMolcas";
    rev = gitLabRev;
    sha256 = "0p2xj8kgqdk5kb1jv5k77acbiqkbl2sh971jnz9p00cmbh556r6a";
  };

  patches = [ (fetchpatch {
    name = "openblas-multiple-output"; # upstream patch
    url = "https://raw.githubusercontent.com/NixOS/nixpkgs/2eee4e4eac851a2846515dcfa3274c4ab92ecbe5/pkgs/applications/science/chemistry/openmolcas/openblasPath.patch";
    sha256 = "0l6z5zhfbfpbp9x58228nhhwwp1fzmi8cmmasvzddp84h31f0b8h";
  })
    ./MKL-MPICH.patch
  ];

  prePatch = ''
    rm -r External/libwfa
    cp -r ${libwfa.src} External/libwfa
    chmod -R u+w External/
  '';

  nativeBuildInputs = [
    perl
    gfortran
    cmake
    texlive.combined.scheme-minimal
    makeWrapper
  ];

  buildInputs = [
    blas.passthru.provider
    hdf5-full
    python
    armadillo
    chemps2
    libxc
  ];

  # tests are not running right now.
  doCheck = false;

  doInstallCheck = true;

  enableParallelBuilding = true;

  NIX_CFLAGS_COMPILE = "-DH5_USE_110_API";

  cmakeFlags = [
    "-DOPENMP=ON"
    "-DTOOLS=ON"
    "-DHDF5=ON"
    "-DFDE=ON"
    "-DWFA=ON"
    "-DCTEST=ON"
    "-DCHEMPS2=ON" "-DCHEMPS2_DIR=${chemps2}/bin"
    "-DEXTERNAL_LIBXC=${libxc}"
  ] ++ lib.lists.optionals (blas.passthru.implementation == "openblas") [
    "-DOPENBLASROOT=${blas.passthru.provider.dev}" "-DLINALG=OpenBLAS"
  ] ++ lib.lists.optionals (blas.passthru.implementation == "mkl") [
    "-DMKLROOT=${blas.passthru.provider}" "-DLINALG=MKL"
  ];

  postConfigure = ''
    # The Makefile will install pymolcas during the build grrr.
    mkdir -p $out/bin
    export PATH=$PATH:$out/bin
  '';

  postFixup = ''
    # Wrong store path in shebang (no Python pkgs), force re-patching
    sed -i "1s:/.*:/usr/bin/env python:" $out/bin/pymolcas
    patchShebangs $out/bin

    wrapProgram $out/bin/pymolcas \
      --set MOLCAS $out \
      --prefix PATH : "${chemps2}/bin"
  '';

  postInstall = ''
    mv $out/pymolcas $out/bin
  '';

  installCheckPhase = ''
     #
     # Minimal check if installation runs properly
     #

     export OMPI_MCA_rmaps_base_oversubscribe=1

     export MOLCAS_WORKDIR=./
     inp=water

     cat << EOF > $inp.xyz
     3
     Angstrom
     O       0.000000  0.000000  0.000000
     H       0.758602  0.000000  0.504284
     H       0.758602  0.000000 -0.504284
     EOF

     cat << EOF > $inp.inp
     &GATEWAY
     coord=water.xyz
     basis=sto-3g
     &SEWARD
     &SCF
     EOF

     $out/bin/pymolcas $inp.inp > $inp.out

     echo "Check for successful run:"
     grep "Happy landing" $inp.status
     echo "Check for correct energy:"
     grep "Total SCF energy" $inp.out | grep 74.880174
  '';

  checkPhase = ''
    make test
  '';

  meta = with lib; {
    description = "Quantum chemistry software package";
    homepage = "https://gitlab.com/Molcas/OpenMolcas";
    maintainers = [ maintainers.markuskowa ];
    license = licenses.lgpl21;
    platforms = platforms.linux;
  };
}
