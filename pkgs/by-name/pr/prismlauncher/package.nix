{
  addDriverRunpath,
  alsa-lib,
  flite,
  gamemode,
  glfw3-minecraft,
  jdk17,
  jdk21,
  jdk8,
  kdePackages,
  lib,
  libGL,
  libX11,
  libXcursor,
  libXext,
  libXrandr,
  libXxf86vm,
  libjack2,
  libpulseaudio,
  libusb1,
  mesa-demos,
  openal,
  pciutils,
  pipewire,
  prismlauncher-unwrapped,
  stdenv,
  symlinkJoin,
  udev,
  vulkan-loader,
  xrandr,
  xorg,
  bubblewrap,
  runCommandLocal,

  additionalLibs ? [ ],
  additionalPrograms ? [ ],
  controllerSupport ? stdenv.hostPlatform.isLinux,
  gamemodeSupport ? false,
  jdks ? [
    jdk21
    jdk17
    jdk8
  ],
  msaClientID ? null,
  textToSpeechSupport ? stdenv.hostPlatform.isLinux,

  enableBubblewrap ? lib.meta.availableOn stdenv.hostPlatform bubblewrap,
}:

assert lib.assertMsg (
  controllerSupport -> stdenv.hostPlatform.isLinux
) "controllerSupport only has an effect on Linux.";

assert lib.assertMsg (
  textToSpeechSupport -> stdenv.hostPlatform.isLinux
) "textToSpeechSupport only has an effect on Linux.";

# `gamemodeSupport` requires session D-Bus access, which is blocked by the sandbox.
assert enableBubblewrap -> !gamemodeSupport;

let
  prismlauncher' = prismlauncher-unwrapped.override { inherit msaClientID; };
in

runCommandLocal "prismlauncher-${prismlauncher'.version}" {
  pname = "prismlauncher";
  inherit (prismlauncher') version;

  paths = [ prismlauncher' ];

  nativeBuildInputs = [ kdePackages.wrapQtAppsHook ];
  nativeBuildInputs =
    [ kdePackages.wrapQtAppsHook ]
    # purposefully using a shell wrapper here for variable expansion
    # see https://github.com/NixOS/nixpkgs/issues/172583
    ++ lib.optional (withWaylandGLFW || enableBubblewrap) makeWrapper;

  buildInputs = [
    kdePackages.qtbase
    kdePackages.qtimageformats
    kdePackages.qtsvg
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux kdePackages.qtwayland;

  postBuild = ''
    wrapQtAppsHook
  '';

  # Passthrough
  # Ref: https://github.com/NixOS/nixpkgs/blob/5e871d8aa6f57cc8e0dc087d1c5013f6e212b4ce/pkgs/build-support/build-fhsenv-bubblewrap/default.nix#L170
  wrapperPreExec = lib.optionalString enableBubblewrap ''
    args=()
    mkdir -p "''${XDG_DATA_HOME:-$HOME/.local/share}/PrismLauncher"
    if [[ "$DISPLAY" == :* ]]; then
        local_socket="/tmp/.X11-unix/X''${DISPLAY#?}"
        args+=(--ro-bind-try "$local_socket" "$local_socket")
    fi
    if [[ "$WAYLAND_DISPLAY" = /* ]]; then
        args+=(--ro-bind-try "$WAYLAND_DISPLAY" "$WAYLAND_DISPLAY")
    elif [[ -n "$WAYLAND_DISPLAY" ]]; then
        args+=(--ro-bind-try "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "/tmp/$WAYLAND_DISPLAY")
    fi
  '';

  bwrapArgs = lib.optionals enableBubblewrap [
    "--unshare-user"
    "--unshare-ipc"
    "--unshare-pid"
    "--unshare-uts"
    "--unshare-cgroup"
    "--die-with-parent"

    "--dev /dev"
    "--proc /proc"
    "--ro-bind /nix /nix"
    "--ro-bind /etc /etc"
    "--tmpfs /tmp"

    # Network is required.
    "--share-net"
    "--ro-bind /run/systemd/resolve /run/systemd/resolve"

    # Mesa & OpenGL.
    "--ro-bind /run/opengl-driver /run/opengl-driver"
    "--dev-bind-try /dev/dri /dev/dri"
    "--ro-bind-try /sys/class /sys/class"
    "--ro-bind-try /sys/dev/char /sys/dev/char"
    "--ro-bind-try /sys/devices/pci0000:00 /sys/devices/pci0000:00"
    "--ro-bind-try /sys/devices/system/cpu /sys/devices/system/cpu"

    # Audio.
    "--setenv XDG_RUNTIME_DIR /tmp"
    ''--ro-bind-try "$XDG_RUNTIME_DIR/pulse" /tmp/pulse''
    ''--ro-bind-try "$XDG_RUNTIME_DIR/pipewire-0" /tmp/pipewire-0''

    # Runtime args from `wrapperPreExec`.
    ''"''${args[@]}"''

    # Data storage.
    ''--bind "''${XDG_DATA_HOME:-$HOME/.local/share}/PrismLauncher" $HOME/.local/share/PrismLauncher''
    "--unsetenv XDG_DATA_HOME"

    # ''--ro-bind-try "''${XDG_CONFIG_DIR:-$HOME/.config}/Kvantum" $HOME/.config/Kvantum''
    # ''--ro-bind-try "''${XDG_CONFIG_DIR:-$HOME/.config}/qt5ct" $HOME/.config/qt5ct''

    # Block dangerous D-Bus.
    "--unsetenv DBUS_SESSION_BUS_ADDRESS"

    "--"
    "${prismlauncher'}/bin/prismlauncher"
  ];

  qtWrapperArgs =
    let
      runtimeLibs = [
        (lib.getLib stdenv.cc.cc)
        ## native versions
        glfw3-minecraft
        openal

        ## openal
        alsa-lib
        libjack2
        libpulseaudio
        pipewire

        ## glfw
        libGL
        libX11
        libXcursor
        libXext
        libXrandr
        libXxf86vm

        udev # oshi

        vulkan-loader # VulkanMod's lwjgl
      ]
      ++ lib.optional textToSpeechSupport flite
      ++ lib.optional gamemodeSupport gamemode.lib
      ++ lib.optional controllerSupport libusb1
      ++ additionalLibs;

      runtimePrograms = [
        mesa-demos
        pciutils # need lspci
        xrandr # needed for LWJGL [2.9.2, 3) https://github.com/LWJGL/lwjgl/issues/128
      ]
      ++ additionalPrograms;

    in
    [ "--prefix PRISMLAUNCHER_JAVA_PATHS : ${lib.makeSearchPath "bin/java" jdks}" ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      "--set LD_LIBRARY_PATH ${addDriverRunpath.driverLink}/lib:${lib.makeLibraryPath runtimeLibs}"
      "--prefix PATH : ${lib.makeBinPath runtimePrograms}"
    ];

  meta = {
    inherit (prismlauncher'.meta)
      description
      longDescription
      homepage
      changelog
      license
      maintainers
      mainProgram
      platforms
      ;
  };
} ''
  ${if enableBubblewrap then ''
    qtWrapperArgs+=(--run "$wrapperPreExec" --add-flags "$bwrapArgs")
    makeQtWrapper ${bubblewrap}/bin/bwrap $out/bin/prismlauncher
  '' else ''
    makeQtWrapper ${prismlauncher'}/bin/prismlauncher $out/bin/prismlauncher
  ''}
  ln -s ${prismlauncher'}/share $out/share
''
