{ stdenv, fetchurl, kdelibs, cmake, gettext, perl, automoc4, qt4, phonon }:

stdenv.mkDerivation rec {
  name = "yakuake-2.9.7";

  src = fetchurl {
    url = "http://download.berlios.de/yakuake/${name}.tar.bz2";
    sha256 = "0azzvbh3jwz8yhn6gqd46ya7589sadfjyysw230vlf0zlfipdlvd";
  };

  buildInputs = [ kdelibs cmake gettext perl automoc4 qt4 phonon ];

  meta = {
    homepage = http://yakuake.kde.org;
    description = "Quad-style terminal emulator for KDE";
    inherit (kdelibs.meta) platforms;
    maintainers = [ stdenv.lib.maintainers.urkud ];
  };
}
