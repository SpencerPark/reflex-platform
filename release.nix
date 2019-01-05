{ local-self ? import ./. {}
}:

let
  inherit (local-self.nixpkgs) lib;
  getOtherDeps = reflex-platform: [
    reflex-platform.ghcjs8_0._dep.stage2Script
    reflex-platform.nixpkgs.cabal2nix
    reflex-platform.ghc.cabal2nix
  ] ++ builtins.concatLists (map
    (crossPkgs: lib.optionals (crossPkgs != null) [
      crossPkgs.buildPackages.haskellPackages.cabal2nix
    ]) [
      reflex-platform.nixpkgsCross.ios.aarch64
      reflex-platform.nixpkgsCross.android.aarch64
      reflex-platform.nixpkgsCross.android.aarch32
    ]
  );

  drvListToAttrs = drvs:
    lib.listToAttrs (map (drv: { inherit (drv) name; value = drv; }) drvs);

  cacheBuildSystems = [
    "x86_64-linux"
    # "i686-linux"
    "x86_64-darwin"
  ];

  perPlatform = lib.genAttrs cacheBuildSystems (system: let
    getRP = args: import ./. ({ inherit system; } // args);
    reflex-platform = getRP {};
    reflex-platform-profiled = getRP { enableLibraryProfiling = true; };
    reflex-platform-legacy-compilers = getRP { __useLegacyCompilers = true; };
    otherDeps = getOtherDeps reflex-platform;

    jsexeHydra = exe: exe.overrideAttrs (attrs: {
      postInstall = ''
        ${attrs.postInstall or ""}
        mkdir -p $out/nix-support
        echo $out/bin/reflex-todomvc.jsexe >> $out/nix-support/hydra-build-products
      '';
    });

    benchmark = import ./scripts/benchmark { inherit reflex-platform; };

    dep = {}
      // reflex-platform.ghcjs8_0._dep
      // reflex-platform.ghcjs8_2._dep
      // reflex-platform.ghcjs8_4._dep
      // (lib.optionalAttrs reflex-platform.androidSupport reflex-platform.ghcAndroidAarch64._dep)
      // benchmark.dep
      ;
  in {
    inherit dep;
    tryReflexShell = reflex-platform.tryReflexShell;
    ghcjs.reflexTodomvc = jsexeHydra reflex-platform.ghcjs.reflex-todomvc;
    ghcjs8_0.reflexTodomvc = jsexeHydra reflex-platform.ghcjs8_0.reflex-todomvc;
    # Doesn't currently build. Removing from CI until fixed.
    # ghcjs8_2.reflexTodomvc = jsexeHydra reflex-platform.ghcjs8_2.reflex-todomvc;
    ghcjs8_4.reflexTodomvc = jsexeHydra reflex-platform.ghcjs8_4.reflex-todomvc;
    ghc.ReflexTodomvc = reflex-platform.ghc.reflex-todomvc;
    ghc8_0.reflexTodomvc = reflex-platform.ghc8_0.reflex-todomvc;
    ghc8_2.reflexTodomvc = reflex-platform.ghc8_2.reflex-todomvc;
    ghc8_4.reflexTodomvc = reflex-platform.ghc8_4.reflex-todomvc;
    profiled = {
      ghc8_0.reflexTodomvc = reflex-platform-profiled.ghc8_0.reflex-todomvc;
      ghc8_2.reflexTodomvc = reflex-platform-profiled.ghc8_2.reflex-todomvc;
      ghc8_4.reflexTodomvc = reflex-platform-profiled.ghc8_4.reflex-todomvc;
    } // lib.optionalAttrs (reflex-platform.androidSupport) {
      inherit (reflex-platform-profiled) androidReflexTodomvc;
      inherit (reflex-platform-profiled) androidReflexTodomvc-8_2;
      inherit (reflex-platform-profiled) androidReflexTodomvc-8_4;
      a = reflex-platform-profiled.ghcAndroidAarch64.a;
    } // lib.optionalAttrs (reflex-platform.iosSupport) {
      inherit (reflex-platform-profiled) iosReflexTodomvc;
      inherit (reflex-platform-profiled) iosReflexTodomvc-8_2;
      inherit (reflex-platform-profiled) iosReflexTodomvc-8_4;
      a = reflex-platform-profiled.ghcIosAarch64.a;
    };
    skeleton-test = import ./skeleton-test.nix { inherit reflex-platform; };
    # TODO update reflex-project-skeleton to also cover ghc80 instead of using legacy compilers option
    skeleton-test-legacy-compilers = import ./skeleton-test.nix { reflex-platform = reflex-platform-legacy-compilers; };
    inherit benchmark;
    cache = reflex-platform.pinBuildInputs "reflex-platform-${system}"
      (builtins.attrValues dep ++ reflex-platform.cachePackages)
      otherDeps;
  } // lib.optionalAttrs (reflex-platform.androidSupport) {
    inherit (reflex-platform) androidReflexTodomvc;
    inherit (reflex-platform) androidReflexTodomvc-8_2;
    inherit (reflex-platform) androidReflexTodomvc-8_4;
    a = reflex-platform.ghcAndroidAarch64.a;
  } // lib.optionalAttrs (reflex-platform.iosSupport) {
    inherit (reflex-platform) iosReflexTodomvc;
    inherit (reflex-platform) iosReflexTodomvc-8_2;
    inherit (reflex-platform) iosReflexTodomvc-8_4;
    a = reflex-platform.ghcIosAarch64.a;
  } // drvListToAttrs otherDeps
    // drvListToAttrs (lib.filter lib.isDerivation reflex-platform.cachePackages) # TODO no filter
  );

  metaCache = local-self.pinBuildInputs
    "reflex-platform-everywhere"
    (map (a: a.cache) (builtins.attrValues perPlatform))
    [];

in perPlatform // { inherit metaCache; }
