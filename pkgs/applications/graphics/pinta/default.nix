{stdenv, fetchurl, mono, gtksharp, pkgconfig}:

stdenv.mkDerivation {
  name = "pinta-0.5";

  src = fetchurl {
    url =  http://github.com/downloads/jpobst/Pinta/pinta-0.5.tar.gz; 
    sha256 = "0qv95zswi488bkbck9b9yhmczj1sgqc96nzn4f5rwfqz516kilrl";
  };

  buildInputs = [mono gtksharp pkgconfig];

  buildPhase = ''
    # xbuild understands pkgconfig, but gtksharp does not give .pc for gdk-sharp
    # So we have to go the GAC-way
    export MONO_GAC_PREFIX=${gtksharp}
    xbuild Pinta.sln
  '';

  # Very ugly - I don't know enough Mono to improve this. Isn't there any rpath in binaries?
  installPhase = ''
    ensureDir $out/lib/pinta $out/bin
    cp bin/*.{dll,exe} $out/lib/pinta
    cat > $out/bin/pinta << EOF
    #!/bin/sh
    export MONO_GAC_PREFIX=${gtksharp}:\$MONO_GAC_PREFIX
    export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${gtksharp}/lib:${gtksharp.gtk}/lib:${mono}/lib
    exec ${mono}/bin/mono $out/lib/pinta/Pinta.exe
    EOF
    chmod +x $out/bin/pinta
  '';

  # Always needed on Mono, otherwise nothing runs
  dontStrip = true; 

  meta = {
    homepage = http://www.pinta-project.com/;
    description = "Drawing/editing program modeled after Paint.NET";
    license = "MIT";
    maintainers = with stdenv.lib.maintainers; [viric];
    platforms = with stdenv.lib.platforms; linux;
  };
}
