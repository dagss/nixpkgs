{ stdenv, fetchurl, kernel ? null, xlibs, gtkLibs, zlib, perl
, # Whether to build the libraries only (i.e. not the kernel module or
  # nvidia-settings).  Used to support 32-bit binaries on 64-bit
  # Linux.
  libsOnly ? false
}:

with stdenv.lib;

let versionNumber = "260.19.36"; in

stdenv.mkDerivation {
  name = "nvidia-x11-${versionNumber}${optionalString (!libsOnly) "-${kernel.version}"}";
  
  builder = ./builder.sh;
  
  src =
    if stdenv.system == "i686-linux" then
      fetchurl {
        url = "http://us.download.nvidia.com/XFree86/Linux-x86/${versionNumber}/NVIDIA-Linux-x86-${versionNumber}.run";
        sha256 = "0vfcfvn59qg53kqkij83pidssfnafd720hrx62cm7jmqzp5vgyvc";
      }
    else if stdenv.system == "x86_64-linux" then
      fetchurl {
        url = "http://us.download.nvidia.com/XFree86/Linux-x86_64/${versionNumber}/NVIDIA-Linux-x86_64-${versionNumber}-no-compat32.run";
        sha256 = "18wqfnmaiz0smf9xbzc3389nwz5lhisq8330bi0z9skwfjlpai2f";
      }
    else throw "nvidia-x11 does not support platform ${stdenv.system}";

  inherit versionNumber libsOnly;

  kernel = if libsOnly then null else kernel;

  dontStrip = true;

  glPath = stdenv.lib.makeLibraryPath [xlibs.libXext xlibs.libX11 xlibs.libXrandr];

  cudaPath = stdenv.lib.makeLibraryPath [zlib stdenv.gcc.gcc];

  programPath = optionalString (!libsOnly) (stdenv.lib.makeLibraryPath
    [ gtkLibs.gtk gtkLibs.atk gtkLibs.pango gtkLibs.glib xlibs.libXv ] );

  buildInputs = [ perl ];

  meta = {
    homepage = http://www.nvidia.com/object/unix.html;
    description = "X.org driver and kernel module for NVIDIA graphics cards";
    license = "unfree";
  };
}
