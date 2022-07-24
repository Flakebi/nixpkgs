{lib, stdenv, fetchFromGitHub, perl, perlPackages, makeWrapper, glibc }:

stdenv.mkDerivation rec {
  version = "3.10";
  pname = "smtp-cli";

  src = fetchFromGitHub {
    owner = "mludvig";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-di1k1n7F/TXsneuM1hsca5GJ4BcohcnByAsSwfwo32E=";
  };

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ perl glibc ]
    ++ (with perlPackages; [
      IOSocketSSL
      DigestHMAC
      TermReadKey
      MIMELite
      FileLibMagic
      IOSocketInet6
      NetDNS
    ]);

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    mv smtp-cli $out/bin
    wrapProgram $out/bin/smtp-cli --prefix PATH : ${perl}/bin \
     --suffix PERL5LIB : $PERL5LIB
  '';

  meta = with lib; {
    homepage = "https://github.com/mludvig/smtp-cli";
    description = "The ultimate command line SMTP client ";
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
