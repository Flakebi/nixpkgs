import ./make-test-python.nix ({ pkgs, ...} :

{
  name = "amdvlk";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ danieldk Flakebi ];
  };

  machine = { ... }:

  {
    imports = [ ./common/x11.nix ];

    hardware.opengl.extraPackages = [
      pkgs.amdvlk
      pkgs.driversi686Linux.amdvlk
    ];
  };

  testScript = { nodes, ... }: ''
    start_all()
    machine.wait_for_x()

    # start vkcube
    machine.succeed(
        "${pkgs.vulkan-tools}/bin/vkcube --validate --c 100"
    )
    machine.succeed(
        "${pkgs.pkgsi686Linux.vulkan-tools}/bin/vkcube --validate --c 100"
    )
  '';
})
