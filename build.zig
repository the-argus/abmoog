const std = @import("std");
const builtin = @import("builtin");
const app_name = "example_c_game";

const release_flags = [_][]const u8{ "-std=c11", "-DNDEBUG", "-DRELEASE" };
const debug_flags = [_][]const u8{"-std=c11"};

var chosen_flags: ?[]const []const u8 = null;

const zcc = @import("compile_commands");

const c_sources = [_][]const u8{
    "src/main.c",
};

const Library = struct {
    // name in build.zig
    remote_name: []const u8,
    // the name given to this library in its build.zig. usually in addStaticLibrary
    artifact_name: []const u8,
    imported: ?*std.Build.Dependency,

    fn artifact(self: @This()) *std.Build.CompileStep {
        return self.imported.?.artifact(self.artifact_name);
    }
};

var libraries = [_]Library{
    .{ .remote_name = "raylib", .artifact_name = "raylib", .imported = null },
    .{ .remote_name = "chipmunk2d", .artifact_name = "chipmunk", .imported = null },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    // keep track of any targets we create
    var targets = std.ArrayList(*std.Build.CompileStep).init(b.allocator);

    for (libraries, 0..) |library, index| {
        libraries[index].imported = b.dependency(library.remote_name, .{
            .target = target,
            .optimize = mode,
        });
    }

    // create executable
    var exe: ?*std.Build.CompileStep = null;
    // emscripten library
    var lib: ?*std.Build.CompileStep = null;

    switch (target.getOsTag()) {
        .wasi, .emscripten => {
            const emscriptenSrc = "build/emscripten/";
            const webOutdir = try std.fs.path.join(b.allocator, &.{ b.install_prefix, "web" });
            const webOutFile = try std.fs.path.join(b.allocator, &.{ webOutdir, "game.html" });

            if (b.sysroot == null) {
                std.log.err("\n\nUSAGE: Pass the '--sysroot \"$EMSDK/upstream/emscripten\"' flag.\n\n", .{});
                return;
            }

            lib = b.addStaticLibrary(.{
                .name = app_name,
                .optimize = mode,
                .target = target,
            });
            try targets.append(lib.?);

            const emscripten_include_flag = try includePrefixFlag(b.allocator, b.sysroot.?);

            lib.?.addCSourceFiles(&c_sources, &[_][]const u8{emscripten_include_flag});
            lib.?.defineCMacro("__EMSCRIPTEN__", null);
            lib.?.defineCMacro("PLATFORM_WEB", null);
            lib.?.addIncludePath(.{ .path = emscriptenSrc });

            const lib_output_include_flag = try includePrefixFlag(b.allocator, b.install_prefix);
            const shell_file = try std.fs.path.join(b.allocator, &.{ emscriptenSrc, "minshell.html" });
            const emcc_path = try std.fs.path.join(b.allocator, &.{ b.sysroot.?, "bin", "emcc" });

            const command = &[_][]const u8{
                emcc_path,
                "-o",
                webOutFile,
                emscriptenSrc ++ "entry.c",
                "-I.",
                "-L.",
                "-I" ++ emscriptenSrc,
                lib_output_include_flag,
                "--shell-file",
                shell_file,
                "-DPLATFORM_WEB",
                "-sUSE_GLFW=3",
                "-sWASM=1",
                "-sALLOW_MEMORY_GROWTH=1",
                "-sWASM_MEM_MAX=512MB", //going higher than that seems not to work on iOS browsers ¯\_(ツ)_/¯
                "-sTOTAL_MEMORY=512MB",
                "-sABORTING_MALLOC=0",
                "-sASYNCIFY",
                "-sFORCE_FILESYSTEM=1",
                "-sASSERTIONS=1",
                "--memory-init-file",
                "0",
                "--preload-file",
                "assets",
                "--source-map-base",
                // "-sLLD_REPORT_UNDEFINED",
                "-sERROR_ON_UNDEFINED_SYMBOLS=0",
                // optimizations
                "-O3",
                // "-Os",
                // "-sUSE_PTHREADS=1",
                // "--profiling",
                // "-sTOTAL_STACK=128MB",
                // "-sMALLOC='emmalloc'",
                // "--no-entry",
                "-sEXPORTED_FUNCTIONS=['_malloc','_free','_main', '_emsc_main','_emsc_set_window_size']",
                "-sEXPORTED_RUNTIME_METHODS=ccall,cwrap",
            };

            const emcc = b.addSystemCommand(command);

            // also statically link the remote libraries
            for (libraries) |library| {
                emcc.addArtifactArg(library.artifact());
            }
            emcc.addArtifactArg(lib.?);
            emcc.step.dependOn(&lib.?.step);

            b.getInstallStep().dependOn(&emcc.step);

            std.fs.cwd().makePath(webOutdir) catch {};

            std.log.info(
                \\
                \\Output files will be in {s}
                \\
                \\---
                \\cd {s}
                \\python -m http.server
                \\---
                \\
                \\building...
            ,
                .{ webOutdir, webOutdir },
            );
        },
        else => {
            exe = b.addExecutable(.{
                .name = app_name,
                .optimize = mode,
                .target = target,
            });
            try targets.append(exe.?);

            chosen_flags = if (mode == .Debug) &debug_flags else &release_flags;

            exe.?.addCSourceFiles(&c_sources, chosen_flags.?);

            // always link libc
            for (targets.items) |t| {
                t.linkLibC();
            }

            // links and includes which are shared across platforms
            try include(targets, "src/");

            // platform-specific additions
            switch (target.getOsTag()) {
                .windows => {},
                .macos => {},
                .linux => {
                    try link(targets, "GL");
                    try link(targets, "X11");
                },
                else => {},
            }

            const run_cmd = b.addRunArtifact(exe.?);
            run_cmd.step.dependOn(b.getInstallStep());
            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step("run", "Run the app");
            run_step.dependOn(&run_cmd.step);
        },
    }

    // make the targets depend on the lib compile steps
    for (&[_]?*std.Build.CompileStep{ exe, lib }) |mainstep| {
        if (mainstep) |step| {
            for (libraries) |library| {
                step.linkLibrary(library.artifact());
            }
        }
    }

    for (targets.items) |t| {
        b.installArtifact(t);
    }

    zcc.createStep(b, "cdb", try targets.toOwnedSlice());
}

fn includePrefixFlag(ally: std.mem.Allocator, path: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(ally, "-I{s}/include", .{path});
}

fn include(
    targets: std.ArrayList(*std.Build.CompileStep),
    path: []const u8,
) !void {
    for (targets.items) |target| {
        target.addIncludePath(.{ .path = path });
    }
}

fn link(
    targets: std.ArrayList(*std.Build.CompileStep),
    lib: []const u8,
) !void {
    for (targets.items) |target| {
        target.linkSystemLibrary(lib);
    }
}
