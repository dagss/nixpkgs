{ cmake, kde, automoc4, kdelibs }:

kde.package rec {
  name = "nuvola-icon-theme-${kde.release}";
  
  # Sources contain primary and kdeclassic as well but they're not installed

  buildInputs = [ cmake automoc4 kdelibs ];
  meta = {
    description = "KDE nuvola icon theme";
    kde = {
      name = "IconThemes";
      module = "kdeartwork";
    };
  };
}
