/* Automatically generated by `update-gcc.sh', do not edit.
   For GCC 4.4.2.  */
{ fetchurl, optional, version, langC, langCC, langFortran, langJava, langAda }:

assert version == "4.4.3";
optional /* langC */ true (fetchurl {
  url = "mirror://gcc/releases/gcc-${version}/gcc-core-${version}.tar.bz2";
  sha256 = "0ml360nwkf95w0ykn19zlyxmdvvzpmrbxj2vfrn0k8i2pvk13wwj";
}) ++
optional langCC (fetchurl {
  url = "mirror://gcc/releases/gcc-${version}/gcc-g++-${version}.tar.bz2";
  sha256 = "1s5zy8pfn4rgfm2l1dpfzrrdhi2l5zhphqk0h3gsbn1pdw751kkv";
}) ++
optional langFortran (fetchurl {
  url = "mirror://gcc/releases/gcc-${version}/gcc-fortran-${version}.tar.bz2";
  sha256 = "0iivw5kgwxdlqamwgaw5zhw48jajsmg09fgynyxkrxsa702s74sw";
}) ++
optional langJava (fetchurl {
  url = "mirror://gcc/releases/gcc-${version}/gcc-java-${version}.tar.bz2";
  sha256 = "13r0yxz6sif3i6sxh7b3fa5m1ygynvsg1bf6ssq6njp1fzp9a2kq";
}) ++
optional langAda (fetchurl {
  url = "mirror://gcc/releases/gcc-${version}/gcc-ada-${version}.tar.bz2";
  sha256 = "146jfkwgg7gdgfqnrm04133amk8k9vr51wc01rwp2bcjai9c3kk7";
}) ++
[]
