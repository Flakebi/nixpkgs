{ stdenvNoCC, fetchgit, lib }:

stdenvNoCC.mkDerivation rec {
  pname = "firmware-linux-nonfree";
  version = "2021-07-16-amdgpu";

  src = fetchgit {
    url = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git";
    rev = "refs/tags/" + lib.replaceStrings ["-"] [""] version;
    sha256 = "185pnaqf2qmhbcdvvldmbar09zgaxhh3h8x9bxn6079bcdpaskn6";
  };

  # Use older amdgpu firmware due to crashes #126771
  postPatch = let
    version_prev = "2021-03-15";
    src_prev = fetchgit {
      url = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git";
      rev = "refs/tags/" + lib.replaceStrings ["-"] [""] version_prev;
      sha256 = "sha256-BnYqveVFJk/tVYgYuggXgYGcUCZT9iPkCQIi48FOTWc=";
    };
  in ''
    rm -r amdgpu/
    cp -r '${src_prev}/amdgpu' ./amdgpu
  '';

  installFlags = [ "DESTDIR=$(out)" ];

  # Firmware blobs do not need fixing and should not be modified
  dontFixup = true;

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "lv3nmvZbrIcqQ9mx14MPSpSIKt2fPPxjHkMbJtBXIeE=";

  meta = with lib; {
    description = "Binary firmware collection packaged by kernel.org";
    homepage = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git";
    license = licenses.unfreeRedistributableFirmware;
    platforms = platforms.linux;
    maintainers = with maintainers; [ fpletz ];
    priority = 6; # give precedence to kernel firmware
  };

  passthru = { inherit version; };
}
