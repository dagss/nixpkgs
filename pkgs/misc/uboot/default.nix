{stdenv, fetchurl, unzip}:

# We should enable this check once we have the cross target system information
# assert stdenv.system == "armv5tel-linux" || crossConfig == "armv5tel-linux";

# All this file is made for the Marvell Sheevaplug
   
stdenv.mkDerivation {
  name = "uboot-2009.11";
   
  src = fetchurl {
    url = "ftp://ftp.denx.de/pub/u-boot/u-boot-2009.11.tar.bz2";
    sha256 = "1rld7q3ww89si84g80hqskd1z995lni5r5xc4d4322n99wqiarh6";
  };

  # patches = [ ./gas220.patch ];

  # Remove the cross compiler prefix, and add reiserfs support
  configurePhase = ''
    make mrproper
    make sheevaplug_config NBOOT=1 LE=1
    sed -i /CROSS_COMPILE/d include/config.mk
  '';

  buildPhase = ''
    unset src
    if test -z "$crossConfig"; then
        make clean all
    else
        make clean all ARCH=arm CROSS_COMPILE=$crossConfig-
    fi
  '';

  buildNativeInputs = [ unzip ];

  dontStrip = true;
  NIX_STRIP_DEBUG = false;

  installPhase = ''
    ensureDir $out
    cp u-boot.bin $out
    cp u-boot u-boot.map $out

    ensureDir $out/bin
    cp tools/{envcrc,mkimage} $out/bin
  '';
}
