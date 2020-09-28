{ lib
, stdenv
, fetchFromGitHub
, rustPlatform
, perl
, pkg-config
, curl
, libiconv
, openssl
}:

rustPlatform.buildRustPackage rec {
  pname = "tauri-bundler";
  version = "0.9.3";

  src = fetchFromGitHub {
    owner = "tauri-apps";
    repo = "tauri";
    rev = "tauri-bundler-v${version}";
    sha256 = "1iginyyw38yaa0pcr28wnyzhl3wzghivyhj3zair287q33vviip5";
  } + "/cli/tauri-bundler";

  cargoPatches = [ ./0001-Add-Cargo.lock.patch ];
  cargoSha256 = "0v525jii6i56kf8kcb4q4l0r7v0kqhalkm4avdic7n5scy0r6ckk";

  #buildInputs = [ openssl ];

  meta = with lib; {
    description = "Wrap rust executables in OS-specific app bundles for Tauri";
    homepage = "https://github.com/tauri-apps/tauri";
    license = licenses.mit;
    maintainers = with maintainers; [ Flakebi ];
  };
}
