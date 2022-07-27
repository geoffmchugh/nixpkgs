{ pkgsi686Linux
, lib
, stdenv
, fetchurl
, dpkg
, mfcj5335dwlpr
, makeWrapper
, coreutils
, ghostscript
, gnugrep
, gnused
, which
, perl
}:

stdenv.mkDerivation rec {
  pname = "mfcj5335dw-cupswrapper";
  version = "1.0.1-0";

  src = fetchurl {
    url = "https://download.brother.com/welcome/dlf103040/mfcj5335dwcupswrapper-${version}.i386.deb";
    sha256 = "237ff18e5d26cec7e1ad95e580ccce6a016c81778e98b93e95e6034bbd6581a9";
  };

  reldir = "opt/brother/Printers/mfcj5335dw/";

  nativeBuildInputs = [ dpkg makeWrapper ];

  unpackPhase = "dpkg-deb -x $src $out";

  installPhase = ''
    basedir=${mfcj5335dwlpr}/${reldir}
    dir=$out/${reldir}
    substituteInPlace $dir/cupswrapper/brother_lpdwrapper_mfcj5335dw \
      --replace /usr/bin/perl ${perl}/bin/perl \
      --replace "basedir =~" "basedir = \"$basedir\"; #" \
      --replace "PRINTER =~" "PRINTER = \"mfcj5535dw\"; #"
    wrapProgram $dir/cupswrapper/brother_lpdwrapper_mfcj5335dw \
      --prefix PATH : ${lib.makeBinPath [ coreutils gnugrep gnused ]}
    mkdir -p $out/lib/cups/filter
    mkdir -p $out/share/cups/model
    ln $dir/cupswrapper/brother_lpdwrapper_mfcj5335dw $out/lib/cups/filter
    ln $dir/cupswrapper/brother_mfcj5335dw_printer_en.ppd $out/share/cups/model
  '';

  meta = with lib; {
    description = "Brother MFC-J5335DW CUPS wrapper driver";
    downloadPage = "http://support.brother.com/g/b/downloadlist.aspx?c=gb&lang=en&prod=mfcj5335dw_eu&os=128";
    homepage = "http://www.brother.com/";
    license = with licenses; gpl2;
    platforms = with platforms; linux;
  };
}
