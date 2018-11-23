{ config ? null, stable ? true } :


let

  qc-cfg = builtins.tryEval (import <qchem-config>);

  cfg = if config == null then
    if qc-cfg.success then
      qc-cfg.value
    else
     {}
  else
    config;

  input = {
    overlays = [ ((import ./default.nix) cfg) ];
    config.allowUnfree=true;
  };

  pkgs = if stable then
    (import <nixpkgs>) input
  else
    (import (fetchGit { url="https://github.com/NixOS/nixpkgs"; })) input;



in {
  openmpiPkgs = {
    inherit (pkgs.openmpiPkgs)
      cp2k
      bagel-mkl-scl
      bagel
      openmolcas
      openmolcas-mkl
      osu-benchmark
      nwchem;
  };

  mpichPkgs = {
    inherit (pkgs.mpichPkgs)
      bagel
      openmolcas
      osu-benchmark
      nwchem;
  };

  mvapichPkgs = {
    inherit (pkgs.mvapichPkgs)
      bagel
      openmolcas
      osu-benchmark
      nwchem;
  };


  extra = {
    inherit (pkgs)
      ibsim
      sos
      openshmem
      osss-ucx
      pmix
      ucx;

  };

  scalapack=pkgs.openmpiPkgs.scalapackCompat-mkl;

  inherit (pkgs)
    cp2k
    bagel
    ergoscf
    fftw
    molcas
    nwchem
    molden
    sharc
    sharc-v1;

   tests = {
     bagel = import ./tests/bagel-native.nix { pkgs=pkgs; bagel=pkgs.bagel; };
     bagelParallel = import ./tests/bagel-parallel.nix { pkgs=pkgs; bagel=pkgs.bagel; };
   };

} // (if builtins.hasAttr "srcurl" cfg then
  {
    inherit (pkgs)
      qdng
      gamess
      gamess-mkl
      mkl
      #impi
      molden;
  }
  else {}
  )
  // (if builtins.hasAttr "licMolpro" cfg then
  {
    inherit (pkgs)
      molpro;
  }
  else {}
  )

