{ lib, stdenv, fetchurl, pkgsi686Linux, dpkg, makeWrapper, coreutils, gnused, gawk, file, cups, util-linux, xxd, runtimeShell
, ghostscript, a2ps }:

# Why:
# The executable "brprintconf_mfcj5335dw" binary is looking for "/opt/brother/Printers/%s/inf/br%sfunc" and "/opt/brother/Printers/%s/inf/br%src".
# Whereby, %s is printf(3) string substitution for stdin's arg0 (the command's own filename) from the 10th char forwards, as a runtime dependency.
# e.g. Say the filename is "0123456789ABCDE", the runtime will be looking for /opt/brother/Printers/ABCDE/inf/brABCDEfunc.
# Presumably, the binary was designed to be deployed under the filename "printconf_mfcj5335dw", whereby it will search for "/opt/brother/Printers/mfcj5335dw/inf/brmfcj5335dwfunc".
# For NixOS, we want to change the string to the store path of brmfcj5335dwfunc and brmfcj5335dwrc but we're faced with two complications:
# 1. Too little room to specify the nix store path. We can't even take advantage of %s by renaming the file to the store path hash since the variable is too short and can't contain the whole hash.
# 2. The binary needs the directory it's running from to be r/w.
# What:
# As such, we strip the path and substitution altogether, leaving only "brmfcj5335dwfunc" and "brmfcj5335dwrc", while filling the leftovers with nulls.
# Fully null terminating the cstrings is necessary to keep the array the same size and preventing overflows.
# We then use a shell script to link and execute the binary, func and rc files in a temporary directory.
# How:
# In the package, we dump the raw binary as a string of search-able hex values using hexdump. We execute the substitution with sed. We then convert the hex values back to binary form using xxd.
# We also write a shell script that invoked "mktemp -d" to produce a r/w temporary directory and link what we need in the temporary directory.
# Result:
# The user can run brprintconf_mfcj5335dw in the shell.

stdenv.mkDerivation rec {
  pname = "mfcj5335dwlpr";
  version = "1.0.1-0";

  src = fetchurl {
    url = "https://download.brother.com/welcome/dlf103016/mfcj5335dwlpr-${version}.i386.deb";
    sha256 = "17da2ebfe13a782cd9a0e42b99a69e7300e26bac5d476732e1e58d32283c8403";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ cups ghostscript dpkg a2ps stdenv.cc.cc.lib ];

  dontUnpack = true;

  brprintconf_mfcj5335dw_script = ''
    #!${runtimeShell}
    cd $(mktemp -d)
    ln -s @out@/usr/bin/brprintconf_mfcj5335dw_patched brprintconf_mfcj5335dw_patched
    ln -s @out@/opt/brother/Printers/mfcj5335dw/inf/brmfcj5335dwfunc brmfcj5335dwfunc
    ln -s @out@/opt/brother/Printers/mfcj5335dw/inf/brmfcj5335dwrc brmfcj5335dwrc
    ./brprintconf_mfcj5335dw_patched "$@"
  '';

  installPhase = ''
    dpkg-deb -x $src $out
    substituteInPlace $out/opt/brother/Printers/mfcj5335dw/lpd/filter_mfcj5335dw \
      --replace /opt "$out/opt"
    substituteInPlace $out/opt/brother/Printers/mfcj5335dw/inf/setupPrintcapij \
      --replace "/opt/brother/Printers" "$out/opt/brother/Printers" \
      --replace "printcap.local" "printcap"

    patchelf --set-interpreter ${pkgsi686Linux.stdenv.cc.libc.out}/lib/ld-linux.so.2 \
      --set-rpath $out/opt/brother/Printers/mfcj5335dw/inf:$out/opt/brother/Printers/mfcj5335dw/lpd \
      $out/opt/brother/Printers/mfcj5335dw/lpd/brmfcj5335dwfilter
    patchelf --add-needed ${stdenv.cc.cc.lib}/lib/libstdc++.so.6 --set-interpreter ${pkgsi686Linux.stdenv.cc.libc.out}/lib/ld-linux.so.2 $out/usr/bin/brprintconf_mfcj5335dw

    #stripping the hardcoded path.
    ${util-linux}/bin/hexdump -ve '1/1 "%.2X"' $out/usr/bin/brprintconf_mfcj5335dw | \
    sed 's.2F6F70742F62726F746865722F5072696E746572732F25732F696E662F6272257366756E63.62726d66636a35333335647766756e63000000000000000000000000000000000000000000.' | \
    sed 's.2F6F70742F62726F746865722F5072696E746572732F25732F696E662F627225737263.62726D66636A3533333564777263000000000000000000000000000000000000000000.' | \
    ${xxd}/bin/xxd -r -p > $out/usr/bin/brprintconf_mfcj5335dw_patched
    chmod +x $out/usr/bin/brprintconf_mfcj5335dw_patched
    #executing from current dir. segfaults if it's not r\w.
    mkdir -p $out/bin
    echo -n "$brprintconf_mfcj5335dw_script" > $out/bin/brprintconf_mfcj5335dw
    chmod +x $out/bin/brprintconf_mfcj5335dw
    substituteInPlace $out/bin/brprintconf_mfcj5335dw --replace @out@ $out

    mkdir -p $out/lib/cups/filter/
    ln -s $out/opt/brother/Printers/mfcj5335dw/lpd/filter_mfcj5335dw $out/lib/cups/filter/brother_lpdwrapper_mfcj5335dw

    wrapProgram $out/opt/brother/Printers/mfcj5335dw/lpd/filter_mfcj5335dw \
      --prefix PATH ":" ${ lib.makeBinPath [ coreutils gnused file ghostscript a2ps ] }
    '';

  meta = with lib; {
    description  = "Brother MFC-J5335DW LPR driver";
    downloadPage = "http://support.brother.com/g/b/downloadlist.aspx?c=gb&lang=en&prod=mfcj5335dw_eu&os=128";
    homepage     = "http://www.brother.com/";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license      = with licenses; unfree;
    platforms    = with platforms; linux;
  };
}
