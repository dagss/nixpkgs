{stdenv, fetchurl, libedit, ghc, perl, gmp, ncurses}:

stdenv.mkDerivation rec {
  version = "6.10.2";
  
  name = "ghc-${version}";
  
  homepage = "http://haskell.org/ghc";

  src = fetchurl {
    url = "${homepage}/dist/${version}/${name}-src.tar.bz2";
    sha256 = "0q3wgp8svfl54kpyp55a1kh63cni5vzz811hqjsps84jdg0lg56m";
  };

  buildInputs = [ghc libedit perl gmp];

  configureFlags=[
    "--with-gmp-libraries=${gmp}/lib"
    "--with-gmp-includes=${gmp}/include"
    "--with-gcc=${stdenv.gcc}/bin/gcc"
  ];

  meta = {
    inherit homepage;
    description = "The Glasgow Haskell Compiler";
  };

  passthru = {
    corePackages = [
      [ "Cabal" "1.6.0.3" ]
      [ "array" "0.2.0.0" ]
      [ "base" "3.0.3.1" ]
      [ "base" "4.1.0.0" ]
      [ "bytestring" "0.9.1.4" ]
      [ "containers" "0.2.0.1" ]
      [ "directory" "1.0.0.3" ]
      [ "editline" "0.2.1.0" ]
      [ "filepath" "1.1.0.2" ]
      [ "(ghc" "6.10.2)" ]
      [ "ghc-prim" "0.1.0.0" ]
      [ "haddock" "2.4.2" ]
      [ "haskell98" "1.0.1.0" ]
      [ "hpc" "0.5.0.3" ]
      [ "integer" "0.1.0.1" ]
      [ "old-locale" "1.0.0.1" ]
      [ "old-time" "1.0.0.2" ]
      [ "packedstring" "0.1.0.1" ]
      [ "pretty" "1.0.1.0" ]
      [ "process" "1.0.1.1" ]
      [ "random" "1.0.0.1" ]
      [ "rts" "1.0" ]
      [ "syb" "0.1.0.1" ]
      [ "template-haskell" "2.3.0.1" ]
      [ "unix" "2.3.2.0" ]
    ];
  };
}
