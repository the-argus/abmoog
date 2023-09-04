{
  description = "Example C game project, with zig as the build system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    supportedSystems = let
      inherit (flake-utils.lib) system;
    in [
      system.aarch64-linux
      system.x86_64-linux
    ];
  in
    flake-utils.lib.eachSystem supportedSystems (system: let
      pkgs = import nixpkgs {inherit system;};

      emsdk = pkgs.linkFarm "emsdk" [
        {
          path = "${pkgs.emscripten}/share/emscripten/cache/sysroot/include";
          name = "include";
        }
        {
          path = "${pkgs.emscripten}/share/emscripten/cache/sysroot/bin";
          name = "bin";
        }
        {
          path = "${pkgs.emscripten}/bin";
          name = "bin";
        }
      ];
    in {
      devShell =
        pkgs.mkShell
        {
          packages =
            (with pkgs; [
              python311 # for running web builds
              gdb
              valgrind
              pkg-config
              libGL
              emsdk
              zig_0_11
            ])
            ++ (with pkgs.xorg; [
              libX11
              libXrandr
              libXinerama
              libXcursor
              libXi
            ]);

          shellHook = ''
            export EMSDK="${emsdk}"
          '';
        };

      formatter = pkgs.alejandra;
    });
}
