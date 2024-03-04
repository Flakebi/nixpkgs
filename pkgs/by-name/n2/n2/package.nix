{ lib
, rustPlatform
, fetchFromGitHub
}:

rustPlatform.buildRustPackage {
  pname = "n2";
  version = "unstable-2024-01-25";

  src = fetchFromGitHub {
    owner = "evmar";
    repo = "n2";
    rev = "668d9ab5cdbd493a8af356078066423487ac81e2";
    hash = "sha256-3tEYjW54skoZ2JV21gvKWHF5yaQ6e2tc+8RuFoWvDa4=";
  };

  cargoHash = "sha256-2uCUgm8/3yiPNqiYfiYsTjPO4dZ9DHmN90fhNwPhdt4=";

  meta = with lib; {
    homepage = "https://github.com/evmar/n2";
    description = "Ninja compatible build system";
    mainProgram = "n2";
    license = licenses.asl20;
    maintainers = with maintainers; [ fgaz ];
    platforms = platforms.all;
  };
}
