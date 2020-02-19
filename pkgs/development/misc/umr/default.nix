{ stdenv, fetchgit, cmake, pkg-config,
  libdrm, libpciaccess, llvmPackages_9, ncurses
}:

stdenv.mkDerivation rec {
  pname = "umr";
  rev = "d1f9f1492df696c956ecbe7369b0e737ae675011";
  version = "git-${rev}";

  src = fetchgit {
    inherit rev;
    url = "https://gitlab.freedesktop.org/tomstdenis/umr";
    sha256 = "0pny5jz396agscyb4wqfsfzlhfnj9sqkgx3m5hp1zl5ccdzm6w4i";
  };

  nativeBuildInputs = [ cmake pkg-config ];

  buildInputs = [
    libdrm
    llvmPackages_9.llvm
    libpciaccess
    ncurses
  ];

  meta = with stdenv.lib; {
    description = "umr is a userspace debugging and diagnostic tool for AMD GPUs using the AMDGPU kernel driver with limited support for driverless debugging.";
    homepage = https://gitlab.freedesktop.org/tomstdenis/umr;
    license = licenses.mit;
    maintainers = with maintainers; [ Flakebi ];
    platforms = platforms.linux;
 };
}
