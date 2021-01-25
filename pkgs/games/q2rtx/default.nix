{ lib, stdenv, fetchFromGitHub, fetchurl, symlinkJoin, cmake, libGL, openal, pkg-config, python3, SDL2, vulkan-headers, vulkan-loader, wayland, xorg, zlib }:

let

  # Some of the data files can be shipped, others must be fetched manually, e.g. by installing the
  # steam version and copying the files into ~/.quake2rtx/baseq2.
  # The needed files are:
  # - players/
  # - pak0.pak
  # - shaders.pkz

  gameDataNoise = fetchurl {
    url = "https://github.com/NVIDIA/Q2RTX/releases/download/v1.0.0/blue_noise.pkz";
    sha256 = "/C/9rhya9iXwk7moY/k943FOndZR51+U4TddnUV1wGU=";
  };

  gameDataMedia = fetchurl {
    url = "https://github.com/NVIDIA/Q2RTX/releases/download/v1.2.0/q2rtx_media.pkz";
    sha256 = "wlsFb3TMQXJzRnLCRtoy+qCaBI/PPmZcJKTfqj5C6jE=";
  };

in
stdenv.mkDerivation rec {
  pname = "q2rtx";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "Q2RTX";
    rev = "v${version}";
    fetchSubmodules = true;
    sha256 = "UztS2drzIB2tIgcVLTujKIjKQ1ug7S7RLEuBiudpw40=";
  };

  patches = [ ./sdl2.patch ./rest.patch ];

  cmakeFlags = [ "-DCONFIG_USE_CURL=OFF" ];

  nativeBuildInputs = [
    cmake
    pkg-config
    python3
    vulkan-headers
  ];

  buildInputs = [
    libGL
    openal
    SDL2
    vulkan-loader
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXinerama
    xorg.libXrender
    xorg.libXext
    xorg.xinput
    xorg.xrandr
    zlib
  ];

  prePatch = ''
    substituteInPlace src/unix/system.c \
      --replace /usr/share/quake2rtx $out/share/quake2rtx
  '';

  installPhase = ''
    install -Dm755 -t $out/bin ../q2rtx

    mkdir -p $out/share/quake2rtx/baseq2
    ln -s ${gameDataNoise} $out/share/quake2rtx/baseq2/blue_noise.pkz
    ln -s ${gameDataMedia} $out/share/quake2rtx/baseq2/q2rtx_media.pkz
  '';

  meta = with lib; {
    description = "NVIDIA’s implementation of RTX ray-tracing in Quake II";
    homepage = "https://github.com/NVIDIA/Q2RTX";
    platforms = platforms.linux;
    license = "Custom";
    maintainers = with maintainers; [ Flakebi ];
  };
}
