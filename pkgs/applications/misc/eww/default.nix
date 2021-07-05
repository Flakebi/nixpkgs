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
  version = "unstable-2021-06-23";

  # TODO Needs a nightly compiler or a patch to add features explicitely
  # a nightly compiler is required unless we use this cheat code.
  RUSTC_BOOTSTRAP=1;

  src = fetchFromGitHub {
    owner = "elkowar";
    repo = pname;
    rev = "10d3d9375fa4e4e522aee9a21585c24e4c0009f5";
    sha256 = "tLcwS8E1Qx7C9GLQcICgfxo3ou1wYmn6d4neQlg3+j0=";
  };

  cargoSha256 = "XuuM5qf6JDDJ5pYlUvfv9Xn0Se+ynNZScJgAJWBboa0=";

  cargoFlags = lib.optionals useWayland [ "--no-default-features" "--features=wayland" ];

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    glib
    gtk3
  ] ++ lib.optionals (!useWayland) [
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    xorg.libxcb
    xorg.libXrender
  ] ++ lib.optionals useWayland [ gtk-layer-shell wayland ];

  meta = with lib; {
    description = "A standalone widget system made in Rust that allows you to implement your own, custom widgets in any window manager";
    homepage = "https://github.com/elkowar/eww";
    license = licenses.mit;
    maintainers = with maintainers; [ Flakebi ];
    platforms = platforms.linux;
  };
}
