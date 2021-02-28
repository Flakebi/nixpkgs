{ lib, stdenv, fetchFromGitHub, rustPlatform, openssl, pam, pkg-config, sqlite, udev
}:

rustPlatform.buildRustPackage rec {
  pname = "kanidm";
  #version = "1.1.0-alpha.3";
  version = "unstable-2021-03-25";

  src = fetchFromGitHub {
    owner = "kanidm";
    repo = "kanidm";
    #rev = "v${version}";
    rev = "254a5e060cc669c696d6dc622a902670a3e7c6d3";
    sha256 = "KvFRg/ibZAolcT0+kWEATCQU8hSZAguYSWScx8XbH4Y=";
  };

  cargoSha256 = "Kh6OdGsoOlqB+mjL1xf8lNLpgtGWAqsfH5Wr21FpbOA=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl pam sqlite udev ];

  postInstall = ''
    ln -s $out/lib/libnss_kanidm.so $out/lib/libnss_kanidm.so.2
  '';

  meta = with lib; {
    homepage = "https://github.com/kanidm/kanidm";
    description = "A simple, secure and fast identity management platform";
    license = licenses.mpl20;
    maintainers = with maintainers; [ Flakebi ];
  };
}
