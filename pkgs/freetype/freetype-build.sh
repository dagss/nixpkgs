#! /bin/sh

. $stdenv/setup || exit 1

tar xvfj $src || exit 1
cd freetype-* || exit 1
LDFLAGS=-Wl,-S ./configure --prefix=$out || exit 1
make || exit 1
make install || exit 1
strip -S $out/lib/*.a || exit 1
