{ kde, cmake, kdelibs, automoc4 }:

kde.package {
  buildInputs = [ cmake kdelibs automoc4 ];


  meta = {
    description = "A KDE 4 project template generator";
    kde = {
      name = "kapptemplate";
      module = "kdesdk";
      version = "0.1";
      versionFile = "kapptemplate/main.cpp";
    };
  };
}
