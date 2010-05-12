{ fetchgit, stdenv, autoconf, automake, libtool, texinfo
, machHeaders, mig, headersOnly ? true }:

let rev = "7913beaef3e6a2c4f7f315a8db7a31dbe1f713e0"; in
stdenv.mkDerivation (rec {
  name = "hurd-0.4-${rev}";

  src = fetchgit {
    url = "git://git.sv.gnu.org/hurd/hurd.git";
    sha256 = "bf4f1376b26b0dcdfd23ff9c9b01440f50d032f48946fad6d3861539978f8f4d";
    inherit rev;
  };

  buildInputs = [ autoconf automake libtool texinfo mig ];
  propagatedBuildInputs = [ machHeaders ];

  configureFlags = "--build=i586-pc-gnu";

  preConfigure = "autoreconf -vfi";

  meta = {
    description = "The GNU Hurd, GNU project's replacement for the Unix kernel";

    longDescription =
      '' The GNU Hurd is the GNU project's replacement for the Unix kernel.
         It is a collection of servers that run on the Mach microkernel to
         implement file systems, network protocols, file access control, and
         other features that are implemented by the Unix kernel or similar
         kernels (such as Linux).
      '';

    license = "GPLv2+";

    homepage = http://www.gnu.org/software/hurd/;

    maintainers = [ stdenv.lib.maintainers.ludo ];
  };
}

//

(if headersOnly
 then { buildPhase = ":"; installPhase = "make install-headers"; }
 else {}))