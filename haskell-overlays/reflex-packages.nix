{ haskellLib
, lib, nixpkgs
, fetchFromGitHub, fetchFromBitbucket, dep
, useFastWeak, useReflexOptimizer, enableTraceReflexEvents, enableLibraryProfiling
}:

with haskellLib;

self: super:

let
  reflexDom = import dep.reflex-dom self nixpkgs;
  jsaddleSrc = dep.jsaddle;
  gargoylePkgs = self.callPackage dep.gargoyle self;
  ghcjsDom = import dep.ghcjs-dom self;
  addReflexTraceEventsFlag = drv: if enableTraceReflexEvents
    then appendConfigureFlag drv "-fdebug-trace-events"
    else drv;
  addReflexOptimizerFlag = drv: if useReflexOptimizer && (self.ghc.cross or null) == null
    then appendConfigureFlag drv "-fuse-reflex-optimizer"
    else drv;
  addFastWeakFlag = drv: if useFastWeak
    then enableCabalFlag drv "fast-weak"
    else drv;
in
{
  ##
  ## Reflex family
  ##

  reflex = dontCheck (addFastWeakFlag (addReflexTraceEventsFlag (addReflexOptimizerFlag (self.callPackage dep.reflex {}))));
  reflex-todomvc = self.callPackage dep.reflex-todomvc {};
  reflex-aeson-orphans = self.callCabal2nix "reflex-aeson-orphans" dep.reflex-aeson-orphans {};
  reflex-dom = addReflexOptimizerFlag reflexDom.reflex-dom;
  reflex-dom-core = appendConfigureFlags
    (addReflexOptimizerFlag reflexDom.reflex-dom-core)
    (lib.optional enableLibraryProfiling "-fprofile-reflex");
  chrome-test-utils = reflexDom.chrome-test-utils;

  ##
  ## GHCJS and JSaddle
  ##

  jsaddle = self.callCabal2nix "jsaddle" "${jsaddleSrc}/jsaddle" {};
  jsaddle-clib = self.callCabal2nix "jsaddle-clib" "${jsaddleSrc}/jsaddle-clib" {};
  jsaddle-webkit2gtk = self.callCabal2nix "jsaddle-webkit2gtk" "${jsaddleSrc}/jsaddle-webkit2gtk" {};
  jsaddle-webkitgtk = self.callCabal2nix "jsaddle-webkitgtk" "${jsaddleSrc}/jsaddle-webkitgtk" {};
  jsaddle-wkwebview = overrideCabal (self.callCabal2nix "jsaddle-wkwebview" "${jsaddleSrc}/jsaddle-wkwebview" {}) (drv: {
    # HACK(matthewbauer): Can’t figure out why cf-private framework is
    #                     not getting pulled in correctly. Has something
    #                     to with how headers are looked up in xcode.
    preBuild = lib.optionalString (!nixpkgs.stdenv.hostPlatform.useiOSPrebuilt) ''
      mkdir include
      ln -s ${nixpkgs.buildPackages.darwin.cf-private}/Library/Frameworks/CoreFoundation.framework/Headers include/CoreFoundation
      export NIX_CFLAGS_COMPILE="-I$PWD/include $NIX_CFLAGS_COMPILE"
    '';

    libraryFrameworkDepends = (drv.libraryFrameworkDepends or []) ++
      (if nixpkgs.stdenv.hostPlatform.useiOSPrebuilt then [
         "${nixpkgs.buildPackages.darwin.xcode}/Contents/Developer/Platforms/${nixpkgs.stdenv.hostPlatform.xcodePlatform}.platform/Developer/SDKs/${nixpkgs.stdenv.hostPlatform.xcodePlatform}.sdk/System"
       ] else with nixpkgs.buildPackages.darwin; with apple_sdk.frameworks; [
         Cocoa
         WebKit
       ]);
  });

  # another broken test
  # phantomjs has issues with finding the right port
  # jsaddle-warp = dontCheck (addTestToolDepend (self.callCabal2nix "jsaddle-warp" "${jsaddleSrc}/jsaddle-warp" {}));
  jsaddle-warp = dontCheck (self.callCabal2nix "jsaddle-warp" "${jsaddleSrc}/jsaddle-warp" {});

  jsaddle-dom = self.callPackage dep.jsaddle-dom {};
  inherit (ghcjsDom) ghcjs-dom-jsffi;

  ##
  ## Gargoyle
  ##

  inherit (gargoylePkgs) gargoyle gargoyle-postgresql gargoyle-postgresql-nix;

  ##
  ## Misc other dependencies
  ##

  haskell-gi-overloading = dontHaddock (self.callHackage "haskell-gi-overloading" "0.0" {});

  monoidal-containers = self.callHackage "monoidal-containers" "0.4.0.0" {};

  # Needs additional instances
  dependent-sum = self.callCabal2nix "dependent-sum" (fetchFromGitHub {
    owner = "obsidiansystems";
    repo = "dependent-sum";
    rev = "9c649ba33fa95601621b4a3fa3808104dd1ababd";
    sha256 = "1msnzdb79bal1xl2xq2j415n66gi48ynb02pf03wkahymi5dy4yj";
  }) {};
  # Misc new features since Hackage relasese
  dependent-sum-template = self.callCabal2nix "dependent-sum-template" (fetchFromGitHub {
    owner = "mokus0";
    repo = "dependent-sum-template";
    rev = "bfe9c37f4eaffd8b17c03f216c06a0bfb66f7df7";
    sha256 = "1w3s7nvw0iw5li3ry7s8r4651qwgd22hmgz6by0iw3rm64fy8x0y";
  }) {};
  # Not on Hackage yet
  dependent-sum-universe-orphans = self.callCabal2nix "dependent-sum-universe-orphans" (fetchFromGitHub {
    owner = "obsidiansystems";
    repo = "dependent-sum-universe-orphans";
    rev = "8c28c09991cd7c3588ae6db1be59a0540758f5f5";
    sha256 = "0dg32s2mgxav68yw6g7b15w0h0z116zx0qri26gprafgy23bxanm";
  }) {};
  # Version 1.2.1 not on Hackage yet
  hspec-webdriver = self.callCabal2nix "hspec-webdriver" (fetchFromBitbucket {
    owner = "wuzzeb";
    repo = "webdriver-utils";
    rev = "a8b15525a1cceb0ddc47cfd4d7ab5a29fdbe3127";
    sha256 = "0csmxyxkxqgx0v2vwphz80515nqz1hpw5v7391fqpjm7bfgy47k4";
  } + "/hspec-webdriver") {};

}
