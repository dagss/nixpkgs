{stdenv, fetchurl}:

stdenv.mkDerivation {
  name = "STLport-5.0.0";
  builder = ./builder.sh;

  src = fetchurl {
    url = mirror://sourceforge/stlport/STLport-5.0.0.tar.bz2;
    md5 = "5aefcbb0c30a91d50bb2d6c7b30e8393";
  };
}
