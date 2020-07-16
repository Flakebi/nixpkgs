{ stdenv, fetchFromGitHub, coreutils, procps, utillinux }:

stdenv.mkDerivation {
  pname = "fish-async-prompt";
  version = "git-20200401";

  src = fetchFromGitHub {
    owner = "acomagu";
    repo = "fish-async-prompt";
    rev = "846fe7befbb049be0ecb1734af4a81e6cf7b0418";
    sha256 = "1g90q58wrc2p4g719d2nphkkd0mb6fl1d31msyszqqz57sqhc1ch";
  };

  installPhase = ''
    mkdir -p $out/share/fish/vendor_conf.d/
    cp conf.d/* $out/share/fish/vendor_conf.d/
    sed -e "s|pgrep|${procps}/bin/pgrep|" \
        -e "s|kill|${utillinux}/bin/kill|" \
        -e "s|tail|${coreutils}/bin/tail|" \
        -e "s|sleep|${coreutils}/bin/sleep|" \
        -i $out/share/fish/vendor_conf.d/*
  '';

  meta = with stdenv.lib; {
    description = "Make your prompt asynchronous in Fish shell";
    license = licenses.mit; # Actually, none
    maintainers = with maintainers; [ Flakebi ];
    platforms = with platforms; unix;
  };
}
