{ stdenv, fetchurl, makeWrapper, autoconf, automake, boost, file, gettext
, glib, glibc, gnome_keyring, gtk, gtkmm, intltool, libctemplate, libglade
, libgnome, libsigcxx, libtool, libuuid, libxml2, libzip, lua, mesa, mysql
, pango, paramiko, pcre, pexpect, pkgconfig, pycrypto, python, sqlite
}:

stdenv.mkDerivation rec {
  pname = "mysql-workbench";
  version = "5.2.31a";
  name = "${pname}-${version}";

  src = fetchurl {
    url = "http://mirror.services.wisc.edu/mysql/Downloads/MySQLGUITools/mysql-workbench-gpl-${version}-src.tar.gz";
    sha256 = "0mvjpin2qmnr8ksiknpcmlqjh5r3mafjcjdrnzbccyxc6r55xiy3";
  };

  buildInputs = [ autoconf automake boost file gettext glib glibc gnome_keyring gtk gtkmm intltool
    libctemplate libglade libgnome libsigcxx libtool libuuid libxml2 libzip lua makeWrapper mesa
    mysql paramiko pcre pexpect pkgconfig pycrypto python sqlite ];

  preConfigure = ''
    substituteInPlace $(pwd)/frontend/linux/workbench/mysql-workbench.in --replace "catchsegv" "${glibc}/bin/catchsegv"

    ./autogen.sh --prefix=$out
  '';

  postInstall = ''
    wrapProgram "$out/bin/mysql-workbench-bin" \
      --prefix LD_LIBRARY_PATH : "${python}/lib" \
      --prefix LD_LIBRARY_PATH : "$(cat ${stdenv.gcc}/nix-support/orig-gcc)/lib64" \
      --prefix PATH : "${gnome_keyring}/bin" \
      --prefix PATH : "${python}/bin" \
      --set PYTHONPATH $PYTHONPATH \
      --run '
# The gnome-keyring-daemon must be running.  To allow for environments like
# kde, xfce where this is not so, we start it first.
# It is cleaned up using a supervisor subshell which detects that
# the parent has finished via the closed pipe as terminate signal idiom,
# used because we cannot clean up after ourselves due to the exec call.

# Start gnome-keyring-daemon, export the environment variables it asks us to set.
for expr in $( gnome-keyring-daemon --components=ssh,pkcs11 --start ) ; do eval "export "$expr ; done

# Prepare fifo pipe.
FIFOCTL="/tmp/gnome-keyring-daemon-ctl.$$.fifo"
[ -p $FIFOCTL ] && rm $FIFOCTL
mkfifo $FIFOCTL

# Supervisor subshell waits reading from pipe, will receive EOF when parent
# closes pipe on termination.  Negate read with ! operator to avoid subshell
# quitting when read EOF returns 1 due to -e option being set.
(
    exec 19< $FIFOCTL
    ! read -u 19

    kill $GNOME_KEYRING_PID
    rm $FIFOCTL
) &

exec 19> $FIFOCTL
            ' 
  '';

  meta = with stdenv.lib; {
    description = "A MySQL visual database modeling, administration and querying tool.";
    longDescription = ''
      MySQL Workbench is a modeling tool that allows you to design
      and generate MySQL databases graphically. It also has administration
      and query development modules where you can manage MySQL server instances
      and execute SQL queries.
    '';

    homepage = http://wb.mysql.com/;
    license = licenses.gpl2;
    maintainers = [ maintainers.kkallio ];
    platforms = platforms.linux;
  };
}
