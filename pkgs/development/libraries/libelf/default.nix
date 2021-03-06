{ fetchurl, stdenv, gettext }:

stdenv.mkDerivation (rec {
  name = "libelf-0.8.13";

  src = fetchurl {
    url = "http://www.mr511.de/software/${name}.tar.gz";
    sha256 = "0vf7s9dwk2xkmhb79aigqm0x0yfbw1j0b9ksm51207qwr179n6jr";
  };

  doCheck = true;

  meta = {
    description = "Libelf, an ELF object file access library";

    homepage = http://www.mr511.de/software/english.html;

    license = "LGPLv2+";

    platforms = stdenv.lib.platforms.all;
    maintainers = [ stdenv.lib.maintainers.ludo ];
  };
}

//

# Gettext is lacking from `stdenv' on Darwin, but not completely, so NLS
# support is enabled but eventually fails.
# FIXME: Eventually make Gettext a build input on all platforms.
(if stdenv.isDarwin
 then { buildInputs = [ gettext ]; }
 else { }))
