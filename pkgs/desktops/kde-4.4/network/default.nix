{ stdenv, fetchurl, lib, cmake, qt4, perl, speex, gmp, libxml2, libxslt, sqlite, alsaLib, libidn
, libvncserver, tapioca_qt, libmsn
, libXi, libXtst, libXdamage, libXxf86vm
, kdelibs, kdepimlibs, automoc4, phonon, qca2, soprano, qimageblitz, strigi}:

stdenv.mkDerivation {
  name = "kdenetwork-4.3.4";
  src = fetchurl {
    url = mirror://kde/stable/4.3.4/src/kdenetwork-4.3.4.tar.bz2;
    sha1 = "e066c3642d254e1e8213ef511546e960c5658596";
  };
  includeAllQtDirs=true;
  CMAKE_PREFIX_PATH=kdepimlibs;
  buildInputs = [ cmake qt4 perl speex gmp libxml2 libxslt sqlite alsaLib libidn
                  libvncserver tapioca_qt libmsn
		  libXi libXtst libXdamage libXxf86vm
                  kdelibs kdepimlibs automoc4 phonon qca2 soprano qimageblitz strigi ];
  meta = {
    description = "KDE network utilities";
    longDescription = "Various network utilities for KDE such as a messenger client and network configuration interface";
    license = "GPL";
    homepage = http://www.kde.org;
    maintainers = [ lib.maintainers.sander ];
  };
}