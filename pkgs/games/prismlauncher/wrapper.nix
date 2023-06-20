{ lib
, stdenv
, makeWrapper
, runCommandLocal
, wrapQtAppsHook
, addOpenGLRunpath

, prismlauncher-unwrapped
, bubblewrap

, qtbase  # needed for wrapQtAppsHook
, qtsvg
, qtwayland
, xorg
, libpulseaudio
, libGL
, glfw
, glfw-wayland-minecraft
, openal
, jdk8
, jdk17
, jdk21
, gamemode
, flite
, glxinfo
, pciutils
, udev
, vulkan-loader
, libusb1

, enableBubblewrap ? lib.meta.availableOn stdenv.hostPlatform bubblewrap
, msaClientID ? null
, gamemodeSupport ? false
, textToSpeechSupport ? stdenv.isLinux
, controllerSupport ? stdenv.isLinux

  # Adds `glfw-wayland-minecraft` to `LD_LIBRARY_PATH`
  # when launched on wayland, allowing for the game to be run natively.
  # Make sure to enable "Use system installation of GLFW" in instance settings
  # for this to take effect
  #
  # Warning: This build of glfw may be unstable, and the launcher
  # itself can take slightly longer to start
, withWaylandGLFW ? false

, jdks ? [ jdk21 jdk17 jdk8 ]
, additionalLibs ? [ ]
, additionalPrograms ? [ ]
}:

assert lib.assertMsg (withWaylandGLFW -> stdenv.isLinux) "withWaylandGLFW is only available on Linux";
# `gamemodeSupport` requires session D-Bus access, which is blocked by the sandbox.
assert enableBubblewrap -> !gamemodeSupport;

let
  prismlauncher' = prismlauncher-unwrapped.override {
    inherit msaClientID gamemodeSupport;
  };

in
runCommandLocal "prismlauncher-${prismlauncher'.version}" {
  nativeBuildInputs = [
    wrapQtAppsHook

    # Force to use the shell wrapper instead of the binary wrapper. We have scripts.
    makeWrapper
  ]
  # purposefully using a shell wrapper here for variable expansion
  # see https://github.com/NixOS/nixpkgs/issues/172583
  ++ lib.optional withWaylandGLFW makeWrapper;

  buildInputs = [
    qtbase
    qtsvg
  ]
  ++ lib.optional (lib.versionAtLeast qtbase.version "6" && stdenv.isLinux) qtwayland;

  waylandPreExec = lib.optionalString withWaylandGLFW ''
    if [ -n "$WAYLAND_DISPLAY" ]; then
      export LD_LIBRARY_PATH=${lib.getLib glfw-wayland-minecraft}/lib:"$LD_LIBRARY_PATH"
    fi
  '';

  # Passthrough
  # Ref: https://github.com/NixOS/nixpkgs/blob/5e871d8aa6f57cc8e0dc087d1c5013f6e212b4ce/pkgs/build-support/build-fhsenv-bubblewrap/default.nix#L170
  wrapperPreExec = lib.optionalString enableBubblewrap ''
    args=()
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

  postBuild = ''
    ${lib.optionalString withWaylandGLFW ''
      qtWrapperArgs+=(--run "$waylandPreExec")
    ''}

    wrapQtAppsHook
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

    ''--ro-bind-try "$HOME/.config" $HOME/.config''
    ''--ro-bind-try "/run/current-system" /run/current-system''
    # Data storage.
    ''--bind "''${XDG_DATA_HOME:-$HOME/.local/share}/PrismLauncher" $HOME/.local/share/PrismLauncher''
    "--unsetenv XDG_DATA_HOME"

    # ''--ro-bind-try "''${XDG_CONFIG_DIR:-$HOME/.config}/Kvantum" $HOME/.config/Kvantum''
    # ''--ro-bind-try "''${XDG_CONFIG_DIR:-$HOME/.config}/qt5ct" $HOME/.config/qt5ct''

    # Block dangerous D-Bus.
    "--unsetenv DBUS_SESSION_BUS_ADDRESS"

    "--"
    # "/nix/store/nwi8rkfs9kigz3nd42fklhjmpb0skg69-coreutils-full-9.1/bin/env"
    "${prismlauncherFinal}/bin/prismlauncher"
  ];

  qtWrapperArgs =
    let
      runtimeLibs = [
        xorg.libX11
        xorg.libXext
        xorg.libXcursor
        xorg.libXrandr
        xorg.libXxf86vm

        # lwjgl
        libpulseaudio
        libGL
        glfw
        openal
        stdenv.cc.cc.lib
        vulkan-loader # VulkanMod's lwjgl

        # oshi
        udev
      ]
      ++ lib.optional gamemodeSupport gamemode.lib
      ++ lib.optional textToSpeechSupport flite
      ++ lib.optional controllerSupport libusb1
      ++ additionalLibs;

      runtimePrograms = [
        xorg.xrandr
        glxinfo
        pciutils # need lspci
      ]
      ++ additionalPrograms;

    in
    [ "--prefix PRISMLAUNCHER_JAVA_PATHS : ${lib.makeSearchPath "bin/java" jdks}" ]
    ++ lib.optionals stdenv.isLinux [
      "--set LD_LIBRARY_PATH ${addOpenGLRunpath.driverLink}/lib:${lib.makeLibraryPath runtimeLibs}"
      # xorg.xrandr needed for LWJGL [2.9.2, 3) https://github.com/LWJGL/lwjgl/issues/128
      "--prefix PATH : ${lib.makeBinPath runtimePrograms}"
    ];

  inherit (prismlauncher') meta;
} ''
  ${if enableBubblewrap then ''
    qtWrapperArgs+=(--run "$wrapperPreExec" --add-flags "$bwrapArgs")
    makeQtWrapper ${bubblewrap}/bin/bwrap $out/bin/prismlauncher
  '' else ''
    makeQtWrapper ${prismlauncherFinal}/bin/prismlauncher $out/bin/prismlauncher
  ''}
  ln -s ${prismlauncherFinal}/share $out/share
''
