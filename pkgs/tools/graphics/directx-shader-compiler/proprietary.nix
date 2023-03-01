{ lib, stdenv, autoPatchelfHook, fetchurl, makeWrapper, directx-shader-compiler, ncurses, zlib }:

# TODO Use finalattrs
stdenv.mkDerivation rec {
  pname = "directx-shader-compiler-proprietary";
  version = "1.7.2212";

  src = fetchurl {
    url = "https://github.com/microsoft/DirectXShaderCompiler/releases/download/v${version}/linux_dxc_2022_12_16.tar.gz";
    hash = "sha256-v7RTvYRNUlddL+DbR3cBwz20UH4UqJ6FEorKhgi1w1k=";
  };

  buildInputs = [ ncurses zlib ];

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  sourceRoot = ".";
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    mkdir -p $out/bin $out/lib
    mv lib/*/libdxil.so $out/lib/

    ln -s ${directx-shader-compiler}/bin/dxc $out/bin/
    ln -s ${directx-shader-compiler}/lib/* $out/lib/

    wrapProgram $out/bin/dxc \
      --prefix LD_LIBRARY_PATH : $out/lib
  '';

  meta = with lib; {
    description = "directx-shader-compiler that includes libdxil.so for signing";
    homepage = "https://github.com/microsoft/DirectXShaderCompiler";
    platforms = with platforms; linux;
    license = "custom";
    maintainers = with maintainers; [ expipiplus1 Flakebi ];
  };
}
