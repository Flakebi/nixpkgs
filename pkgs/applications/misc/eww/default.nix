{ lib
, fetchFromGitHub
, glib
, gtk-layer-shell
, gtk3
, pkg-config
, rustPlatform
, wayland
, xorg
, useWayland ? false,
}:

rustPlatform.buildRustPackage rec {
  pname = "eww";
  version = "unstable-2021-05-03";

  # TODO Needs a nightly compiler

  src = fetchFromGitHub {
    owner = "elkowar";
    repo = pname;
    rev = "9ea20cd7537bd9637c42e36ba260e360f5d51440";
    sha256 = "LPA2wu5ACv2n+y0JLD7o8q3JTtCzjcEGzLNmL8DZBkI=";
  };

  cargoFlags = lib.optionals useWayland [ "--no-default-features" "--features=wayland" ];

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    glib
    gtk3
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    xorg.libxcb
    xorg.libXrender
  ] ++ lib.optionals useWayland [ gtk-layer-shell wayland ];

  cargoSha256 = "9dtW8tg93ju9Bx+PI9IahUHOSXpnajTv8BUgio6BoHs=";

  meta = with lib; {
    description = "A standalone widget system made in Rust that allows you to implement your own, custom widgets in any window manager";
    homepage = "https://github.com/elkowar/eww";
    license = licenses.mit;
    maintainers = with maintainers; [ Flakebi ];
    platforms = platforms.linux;
  };
}
