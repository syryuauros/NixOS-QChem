final: prev:

let

  cfg =
    if (builtins.hasAttr "qchem-config" prev.config) then
      (import ./cfg.nix) prev.config.qchem-config
    else
      (import ./cfg.nix) { allowEnv = true; }; # if no config is given allow env

  inherit (prev) lib;

  # Create a stdenv with CPU optimizations
  makeOptStdenv = stdenv: arch: extraCflags: if arch == null then stdenv else
  stdenv.override (old: {
    name = old.name + "-${arch}";

    # Make sure respective CPU features are set
    hostPlatform = old.hostPlatform //
      lib.mapAttrs (p: a: a arch) lib.systems.architectures.predicates;

    # Add additional compiler flags
    extraAttrs = {
      mkDerivation = args: stdenv.mkDerivation (args // {
        NIX_CFLAGS_COMPILE = toString (args.NIX_CFLAGS_COMPILE or "")
          + " -march=${arch} -mtune=${arch} " + extraCflags;
      });
    };
  });

  # stdenv with CPU flags
  optStdenv = makeOptStdenv final.stdenv cfg.optArch "";

  # stdenv with extra optimization flags, use selectively
  aggressiveStdenv = makeOptStdenv final.stdenv cfg.optArch "-O3 -fomit-frame-pointer -ftree-vectorize";


  #
  # Our package set
  #
  overlay = subset: extra:
    let
      super = prev;
      self = final."${subset}";
      callPackage = super.lib.callPackageWith (final // self);
      pythonOverrides = (import ./pythonPackages.nix) subset;

      optUpstream = import ./nixpkgs-opt.nix final prev self optStdenv;

    in
    {
      "${subset}" = optUpstream // {

        pkgs = final;

        inherit callPackage;
        inherit aggressiveStdenv;

        #
        # Upstream overrides
        #

        # For molcas and chemps2
        hdf5-full = final.hdf5.override {
          cppSupport = true;
          fortranSupport = true;
        };

        fftw-mpi = self.fftw.override { enableMpi = true; };

        # Non-GUI version
        octave-opt = (final.octave.override {
          inherit (self.aggressiveStdenv) mkDerivation;
          enableJava = true;
          jdk = super.jdk8;
          inherit (final)
            hdf5
            ghostscript
            glpk
            suitesparse
            gnuplot;
        }).overrideAttrs (x: { preCheck = "export OMP_NUM_THREADS=4"; });

        # GUI version
        octave = (final.octaveFull.override {
          enableJava = true;
          jdk = super.jdk8;
          inherit (final)
            hdf5
            ghostscript
            glpk
            suitesparse
            gnuplot;
        }).overrideAttrs (x: { preCheck = "export OMP_NUM_THREADS=4"; });

        # Allow to provide a local download source for unfree packages
        requireFile = if cfg.srcurl == null then super.requireFile else
        { name, sha256, ... }:
        super.fetchurl {
          url = cfg.srcurl + "/" + name;
          inherit sha256;
        };

        # Return null if x == null otherwise return the argument
        nullable = x: ret: if x == null then null else ret;

        #
        # Applications
        #
        autoint = super.python3.pkgs.toPythonApplication self.python3.pkgs.pyphspu;

        bagel = callPackage ./pkgs/apps/bagel {
          boost = final.boost165;
        };

        bagel-serial = callPackage ./pkgs/apps/bagel {
          enableMpi = false;
          boost = final.boost165;
        };

        cefine = self.nullable self.turbomole (callPackage ./pkgs/apps/cefine { });

        cfour = callPackage ./pkgs/apps/cfour {
          blas = final.blas-ilp64;
          lapack = final.lapack-ilp64;
        };

        chemps2 = callPackage ./pkgs/apps/chemps2 { };

        crest = callPackage ./pkgs/apps/crest { };

        dalton = callPackage ./pkgs/apps/dalton { };

        dftd3 = callPackage ./pkgs/apps/dft-d3 { };

        dirac = callPackage ./pkgs/apps/dirac {
          inherit (self) exatensor;
        };

        dkh = callPackage ./pkgs/apps/dkh { };

        exatensor = callPackage ./pkgs/apps/exatensor { };

        gamess-us = callPackage ./pkgs/apps/gamess-us {
          blas = final.blas-ilp64;
        };

        gator = super.python3.pkgs.toPythonApplication self.python3.pkgs.gator;

        gaussview = callPackage ./pkgs/apps/gaussview { };

        gdma = callPackage ./pkgs/apps/gdma { };

        gpaw = super.python3.pkgs.toPythonApplication self.python3.pkgs.gpaw;

        harminv = callPackage ./pkgs/apps/harminv { };

        iboview = prev.libsForQt5.callPackage ./pkgs/apps/iboview { };

        janpa = callPackage ./pkgs/apps/janpa { };

        luscus = callPackage ./pkgs/apps/luscus { };

        nwchem = callPackage ./pkgs/apps/nwchem {
          blas = final.blas-ilp64;
          lapack = final.lapack-ilp64;
        };

        mctdh = callPackage ./pkgs/apps/mctdh { };

        meep = super.python3.pkgs.toPythonApplication self.python3.pkgs.meep;

        molcas1809 = callPackage ./pkgs/apps/openmolcas/v18.09.nix {
          blas = final.blas-ilp64;
          gfortran = final.gfortran9;
        };

        molcas = let
          molcasOpt = prev.openmolcas.override {
            stdenv = aggressiveStdenv;
            hdf5-cpp = self.hdf5-full;
          };
        in molcasOpt.overrideAttrs (oldAttrs: {
          buildInputs = oldAttrs.buildInputs ++ [ self.chemps2 ];
          cmakeFlags = oldAttrs.cmakeFlags ++ [
            "-DWFA=ON"
            "-DCHEMPS2=ON" "-DCHEMPS2_DIR=${self.chemps2}/bin"
          ];
          prePatch = ''
            rm -r External/libwfa
            cp -r ${self.libwfa.src} External/libwfa
            chmod -R u+w External/
          '';
        });

        moltemplate = super.python3.pkgs.toPythonApplication self.python3.pkgs.moltemplate;

        mrcc = callPackage ./pkgs/apps/mrcc { };

        mrchem = callPackage ./pkgs/apps/mrchem { };

        mt-dgemm = callPackage ./pkgs/apps/mt-dgemm { };

        multiwfn = callPackage ./pkgs/apps/multiwfn { };

        gmultiwfn = callPackage ./pkgs/apps/gmultiwfn { };

        openmm = super.python3.pkgs.toPythonApplication self.python3.pkgs.openmm;

        orca = callPackage ./pkgs/apps/orca { };

        orient = callPackage ./pkgs/apps/orient { };

        osu-benchmark = callPackage ./pkgs/apps/osu-benchmark {
          # OSU benchmark fails with C++ binddings enabled
          mpi = self.mpi.overrideAttrs (x: {
            configureFlags = super.lib.remove "--enable-mpi-cxx" x.configureFlags;
          });
        };

        packmol = callPackage ./pkgs/apps/packmol { };

        pegamoid = self.python3.pkgs.callPackage ./pkgs/apps/pegamoid { };

        pdbfixer = super.python3.pkgs.toPythonApplication self.python3.pkgs.pdbfixer;

        psi4 = super.python3.pkgs.toPythonApplication self.python3.pkgs.psi4;

        pysisyphus = super.python3.pkgs.toPythonApplication self.python3.pkgs.pysisyphus;

        q-chem-installer = callPackage ./pkgs/apps/q-chem/installer.nix { };

        qdng = callPackage ./pkgs/apps/qdng {
          stdenv = aggressiveStdenv;
          protobuf = super.protobuf3_11;
        };

        qmcpack = callPackage ./pkgs/apps/qmcpack { };

        # blank version
        sharc = callPackage ./pkgs/apps/sharc/default.nix {
          bagel = self.bagel-serial;
          molpro = self.molpro12; # V2 only compatible with versions up to 2012
          gaussian = if cfg.optpath != null then self.gaussian else null;
        };

        sharc-full = self.sharc.override {
          enableBagel = true;
          enableMolcas = true;
          enableMolpro = if self.molpro12 != null then true else false;
          enableOrca = if self.orca != null then true else false;
          enableTurbomole = if self.turbomole != null then true else false;
          enableGaussian = if self.gaussian != null then true else false;
        };

        sharc-bagel = self.sharc.override { enableBagel = true; };

        sharc-gaussian = with self; nullable gaussian (sharc.override { enableGaussian = true; });

        sharc-molcas = self.sharc.override { enableMolcas = true; };

        sharc-molpro = with self; nullable molpro12 (sharc.override { enableMolpro = true; });

        sharc-orca = with self; nullable orca (sharc.override { enableOrca = true; });

        sharc-turbomole = with self; nullable turbomole (sharc.override { enableTurbomole = true; });


        stream-benchmark = callPackage ./pkgs/apps/stream { };

        tinker = callPackage ./pkgs/apps/tinker { };

        travis-analyzer = callPackage ./pkgs/apps/travis-analyzer { };

        turbomole = callPackage ./pkgs/apps/turbomole { };

        veloxchem = super.python3.pkgs.toPythonApplication self.python3.pkgs.veloxchem;

        vmd =
          if cfg.useCuda
          then callPackage ./pkgs/apps/vmd/binary.nix { }
          else callPackage ./pkgs/apps/vmd { }
        ;

        vossvolvox = callPackage ./pkgs/apps/vossvolvox { };

        wfaMolcas = self.libwfa.override { buildMolcasExe = true; };

        wfoverlap = callPackage ./pkgs/apps/wfoverlap {
          blas = final.blas-ilp64;
          lapack = final.lapack-ilp64;
        };

        wxmacmolplt = callPackage ./pkgs/apps/wxmacmolplt { };

        xtb = callPackage ./pkgs/apps/xtb { };

        ### Python packages
        python3 = super.python3.override (old: {
          packageOverrides = super.lib.composeExtensions (old.packageOverrides or (_: _: { })) (pythonOverrides cfg self super);
        });

        python2 = super.python2.override (old: {
          packageOverrides = super.lib.composeExtensions (old.packageOverrides or (_: _: { })) (pythonOverrides cfg self super);
        });

        #
        # Libraries
        #

        amd-fftw = callPackage ./pkgs/lib/amd-fftw { };

        amd-scalapack = callPackage ./pkgs/lib/amd-scalapack { };

        libecpint = callPackage ./pkgs/lib/libecpint { };

        libefp = callPackage ./pkgs/lib/libefp { };

        libGDSII = callPackage ./pkgs/lib/libGDSII { };

        libtensor = callPackage ./pkgs/lib/libtensor { };

        libvdwxc = callPackage ./pkgs/lib/libvdwxc { };

        libwfa = callPackage ./pkgs/lib/libwfa { };

        mrcpp = callPackage ./pkgs/lib/mrcpp { };

        ucc = callPackage ./pkgs/lib/ucc { enableCuda = cfg.useCuda; };
        #
        # Utilities
        #

        nixGL = callPackage ./pkgs/apps/nixgl { };

        writeScriptSlurm = callPackage ./builders/slurmScript.nix { };

        slurm-tools = callPackage ./pkgs/apps/slurm-tools { };

        project-shell = callPackage ./pkgs/apps/project-shell { };

        # A wrapper to enforce license checkouts with slurm
        slurmLicenseWrapper = callPackage ./builders/licenseWrapper.nix { };

        # build bats tests
        batsTest = callPackage ./builders/batsTest.nix { };

        # build a benchmark script
        #benchmarkScript = callPackage ./builders/benchmark.nix { };

        # benchmark set builder
        benchmarks = callPackage ./benchmark/default.nix { };

        benchmarksets = callPackage ./tests/benchmark-sets.nix {
          inherit callPackage;
        };

        tests = with self; {
          cfour = nullable cfour (callPackage ./tests/cfour { });
          cp2k = callPackage ./tests/cp2k { };
          bagel = callPackage ./tests/bagel { };
          bagel-bench = callPackage ./tests/bagel/bench-test.nix { };
          dalton = callPackage ./tests/dalton { };
          hpcg = callPackage ./tests/hpcg { };
          hpl = callPackage ./tests/hpl { };
          molcas = callPackage ./tests/molcas { };
          molpro = nullable molpro (callPackage ./tests/molpro { });
          mrcc = nullable mrcc (callPackage ./tests/mrcc { });
          nwchem = callPackage ./tests/nwchem { };
          psi4 = callPackage ./tests/psi4 { };
          pyscf = callPackage ./tests/pyscf { };
          qdng = nullable qdng (callPackage ./tests/qdng { });
          dgemm = callPackage ./tests/dgemm { };
          stream = callPackage ./tests/stream { };
          turbomole = nullable turbomole (callPackage ./tests/turbomole { });
          xtb = callPackage ./tests/xtb { };
        };

        testFiles =
          let
            batsDontRun = self.batsTest.override { overrideDontRun = true; };
          in
          builtins.mapAttrs (n: v: v.override { batsTest = batsDontRun; })
            self.tests;

        # provide null molpro attrs in case there is no license
        molpro = null;
        molpro12 = null;
        molpro20 = null;
        molpro-ext = null;

        q-chem = null;

        # Provide null gaussian attrs in case optpath is not set
        gaussian = null;
      } // lib.optionalAttrs (cfg.licMolpro != null) {

        #
        # Molpro packages
        #
        molpro = self.molpro20;

        molpro-pr = self.molpro.override { comm = "mpipr"; };

        molpro12 = callPackage ./pkgs/apps/molpro/2012.nix { token = cfg.licMolpro; };

        molpro20 = callPackage ./pkgs/apps/molpro { token = cfg.licMolpro; };

        molpro-ext = callPackage ./pkgs/apps/molpro/custom.nix { token = cfg.licMolpro; };

      } // lib.optionalAttrs (cfg.licQChem != null) {
        q-chem = callPackage ./pkgs/apps/q-chem/default.nix {
          qchemLicensePath = cfg.licQChem;
        };
      } // lib.optionalAttrs (cfg.optpath != null) {
        #
        # Quirky packages that need to reside outside the nix store
        #
        gaussian = callPackage ./pkgs/apps/gaussian { inherit (cfg) optpath; };

        matlab = callPackage ./pkgs/apps/matlab { inherit (cfg) optpath; };

      } // extra;
    };

in
overlay cfg.prefix { }
