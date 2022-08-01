// const std = @import("std");

// pub fn build(b: *std.build.Builder) void {
//     // Standard target options allows the person running `zig build` to choose
//     // what target to build for. Here we do not override the defaults, which
//     // means any target is allowed, and the default is native. Other options
//     // for restricting supported target set are available.
//     const target = b.standardTargetOptions(.{});

//     // Standard release options allow the person running `zig build` to select
//     // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
//     const mode = b.standardReleaseOptions();

//     const exe = b.addExecutable("game", "src/main.zig");
//     exe.setTarget(target);
//     exe.setBuildMode(mode);
//     exe.install();

//     const run_cmd = exe.run();
//     run_cmd.step.dependOn(b.getInstallStep());
//     if (b.args) |args| {
//         run_cmd.addArgs(args);
//     }

//     const run_step = b.step("run", "Run the app");
//     run_step.dependOn(&run_cmd.step);
// }


const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .gnu } });
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("asteroidz", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    const sdl_path = "C:\\lib\\SDL2-2.0.14\\";
    exe.addIncludeDir(sdl_path ++ "include");
    exe.addLibPath(sdl_path ++ "lib\\x64");
    b.installBinFile(sdl_path ++ "lib\\x64\\SDL2.dll", "SDL2.dll");
    exe.linkSystemLibrary("sdl2");


    exe.addLibPath("C:\\Odin\\vendor\\sdl2\\ttf");
    exe.linkSystemLibrary("SDL2_ttf");


    const sdl_ttf_path = "C:\\Users\\JoshPC\\Downloads\\SDL_ttf-release-2.20.0-source\\SDL_ttf-release-2.20.0";
    exe.addIncludeDir(sdl_ttf_path);
    b.installBinFile("C:\\Users\\JoshPC\\Downloads\\SDL2_ttf-2.20.0-win32-x64\\SDL2_ttf.dll", "SDL2_ttf.dll");



    exe.linkLibC();
    exe.install();
}
