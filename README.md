# Raylib/Chipmunk Game Project Template

A flexible C game project template. This project:

- Can be built on Windows/Mac/Linux hosts for Windows/Mac/Linux/Web targets.
  (MacOS hosts and targets are currently untested)
- Includes drawing, asset loading, 2D physics, and vector/matrix math.
- Uses Zig as the build system, making it easy to use C++ or Zig in place of C.
- Generates `compile_commands.json`
- Includes a nix flake environment, making it very easy to set up on Mac or Linux

This project does not create any abstraction over raylib and chipmunk, it simply
includes them in the build. This means you will have to deal with the fact that
both libraries have their own implementations of vectors and matrices.

## Raylib

Raylib is an extremely simple yet very complete and easy-to use C API for
creating games. It has almost everything I ever need, with the exception of
physics. I believe this is because raylib tries to be as transparent as possible
in terms of state, so doing something like managing a ton of objects in a
simulation is out of its wheelhouse.

To see if raylib is right for you, check out the [cheatsheet](https://www.raylib.com/cheatsheet/cheatsheet.html).

## Chipmunk2D

Chipmunk2D is my 2D physics library of choice. See the [Hello Chipmunk](https://chipmunk-physics.net/release/ChipmunkLatest-Docs/#Intro-HelloChipmunk)
example to get an idea of what the API is like.

## Planned Features

- Make it easy to swap out Chipmunk for ODE or Bullet for 3D games.
- Hot reloading, probably by using the [MIR](https://github.com/vnmakarov/mir)
  JIT compiler. Unfortunately this JIT only works on Mac/Linux. Might consider
  another JIT for windows support.

## Setup

All platforms can perform native and cross-compiled builds in the same way, with
the exception of web builds, which require additional setup. See the [Nix](#nix)
section if you have nix installed and want to avoid this manual way of doing
things. Otherwise:

To build this project on your machine, first clone the repository with your
favorite git client. Then, head to [https://ziglang.org/download/](https://ziglang.org/download/)
to find a list of zig downloads. Scroll down to the section marked `0.11.0`.
Download the correct 0.11.0 binary for your OS and CPU architecture. Untar (or,
in the case of windows, unzip) the file in your downloads folder. You should end
up with a folder with a `zig.exe` or `zig` executable. Now, if you want to
execute zig commands, you would have to type the full path to this executable.
If you want to avoid this (believe me, you do) then look up how to add a folder
to PATH for your OS. Here are the first articles I found when looking it up:

- [Windows](https://helpdeskgeek.com/windows-10/add-windows-path-environment-variable/)
- [Linux](https://www.howtogeek.com/658904/how-to-add-a-directory-to-your-path-in-linux/)
- [MacOS](https://techpp.com/2021/09/08/set-path-variable-in-macos-guide/)

Once you have done this, you can open a terminal or cmd.exe, `cd` to the folder
with your project, and run `zig build run`. The project should build and a window
with a red rotating square should appear.

## VSCode

In order to set up vscode, install the `clangd` extension. This may conflict with
Microsoft's C/C++ intellisense, in which case just disable the Microsoft one.
Then, open a terminal (if you have the folder open you can right click on it
and select "Open Integrated Terminal" from the pop-up) and run `zig build cdb`.
This will create a file called `compile_commands.json`, which clangd will read
and use to provide intellisense. If you add or move files in your project, or
add new libraries, you will need to run `zig build cdb` again to update intellisense.

## Adding and moving source files

If you want to rename, move, or add a new source file, you will need to edit the
build.zig file. Inside there is an array of strings called `c_sources`. Make sure
that all the files you want to be compiled in your project are listed there,
surrounded by double quotes and separated by commas.

If you are using clangd and compile_commands.json, you must also re-run
`zig build cdb` to get updated intellisense.

## Building for Web

You will need to install the emscripten SDK first and foremost. After that, you
just need to provide its location to zig with the zig build flag ``--sysroot``.
Here is the typical build command for web, on a machine using a POSIX shell:

```bash
zig build \
    -Doptimize=ReleaseSmall \
    -Dtarget=wasm32-emscripten \
    --sysroot "$EMSDK" \
    --verbose-cc
```

Notice the `wasm32-emscripten` platform. Also, the `$EMSDK` is a variable which
resolves to the path to the SDK. You can just manually copy and paste the path
instead, for simplicity.

## Using C++ instead of C

To use C++, you will need to perform some edits to the build.zig. Find the
following line:

```zig
t.linkLibC();
```

and add, directly after it:

```zig
t.linkLibCpp();
```

After doing this, you can simply rename `main.c` to `main.cpp` and start using
c++ features.

Additionally, if you want to do web builds in the future, you will need to replace
the `emcc_executable` variable (which is currently `"emcc"`) with `"em++"`.

## Nix

If you don't know what the flake.nix file is, go ahead and delete flake.nix,
flake.lock, and .envrc.

If you do know what they are, then great. Now install nix and direnv-flakes and
run `direnv allow` in the project directory. Nix will automatically download and
install zig, gdb, valgrind, etc.

## Credits

Credit to `@ryupold` on GitHub for writing a large portion of the code present
in the `build.zig`. Copied from their [raylib.zig cross platform examples](https://github.com/ryupold/examples-raylib.zig).

## Licensing

This is under the same open-source license as raylib: zlib/libpng.
