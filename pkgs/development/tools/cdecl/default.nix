{stdenv, fetchurl, yacc, flex, readline, ncurses}:

stdenv.mkDerivation {
  name = "cdecl-2.5";
  src = fetchurl {
    url = ftp://metalab.unc.edu/pub/linux/devel/lang/c/cdecl-2.5.tar.gz;
    md5 = "29895dab52e85b2474a59449e07b7996";
  };

  patches = [ ./cdecl-2.5.patch ];
  preBuild = "
    makeFlags=\"PREFIX=$out\"
  ";
  buildInputs = [yacc flex readline ncurses];

  meta = {
    description = "Translator English -- C/C++ declarations";
  };
}
