{ stdenv, fetchurl, perlSupport, libX11, libXt, libXft, ncurses, perl }:

let 
  name = "rxvt-unicode";
  version = "9.07";
  n = "${name}-${version}";
in

stdenv.mkDerivation (rec {

  name = "${n}${if perlSupport then "-with-perl" else ""}";

  src = fetchurl {
    url = "http://dist.schmorp.de/rxvt-unicode/rxvt-unicode-9.07.tar.bz2";
    sha256 = "18y5mb3cm1gawjm723q5r7yk37s9drzg39kna036i694m2667865";
  };

  buildInputs =
    [ libX11 libXt libXft ncurses /* required to build the terminfo file */ ]
    ++ stdenv.lib.optional perlSupport perl;

  preConfigure =
    ''
      configureFlags="${if perlSupport then "--enable-perl" else "--disable-perl"}";
      export TERMINFO=$out/share/terminfo # without this the terminfo won't be compiled by tic, see man tic
    ''
    # make urxvt find its perl file lib/perl5/site_perl is added to PERL5LIB automatically
    + stdenv.lib.optionalString perlSupport ''
      ensureDir $out/lib/perl5
      ln -s $out/{lib/urxvt,lib/perl5/site_perl}
    '';

  meta = {
    description = "A clone of the well-known terminal emulator rxvt";
    longDescription = "
      You should put this into your ~/.bashrc:
      export TERMINFO=~/.nix-profile/share/terminfo
    ";
    homepage = "http://software.schmorp.de/pkg/rxvt-unicode.html";
  };
})
