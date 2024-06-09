const std = @import("std");

const suggested_version = "0.1.1";

pub fn build(b: *std.Build) void {
    const dev_install = b.option(bool, "dev-install", "Install the icon and desktop file") orelse false;
    const stable = b.option(bool, "stable", "Configure the application to the stable appearance") orelse false;
    const build_id = b.option(u16, "build-id", "Manually specify a value") orelse std.crypto.random.int(u16);
    const version = b.option([]const u8, "version", "Manually specify a value") orelse suggested_version;
    
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
        
    const exe = b.addExecutable(.{
        .name = "crates",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize
    });
    exe.linkLibC();
    exe.linkSystemLibrary2("libadwaita-1", .{ .preferred_link_mode = .dynamic, .weak = true });
    
    // When cross compiling architecture specific libraries are needed.
    // While surprisingly no distribution I use allows conveniently downloading those, it is fairly easy
    // to do so using a container (if a bit wasteful).
    // TODO: Write a program/script to download cross compilation libraries from a distribution's mirror.
    if (!target.query.isNative()) {
        if (target.result.cpu.arch == .x86_64) {
            exe.addLibraryPath(b.path("cross/x86_64/merged/usr/lib64"));
            exe.addIncludePath(b.path("cross/x86_64/merged/usr/include"));
        } else if (target.result.cpu.arch == .aarch64) {
            exe.addLibraryPath(b.path("cross/aarch64/merged/usr/lib64"));
            exe.addIncludePath(b.path("cross/aarch64/merged/usr/include"));
        }
    }
    
    const options = b.addOptions();
    options.addOption(bool, "stable", stable);
    options.addOption(u16, "build_id", build_id);
    options.addOption([]const u8, "version", version);
    exe.root_module.addOptions("config", options);
    
    _ = b.run(&.{ "sh", "-c", "cd resources; glib-compile-resources resources.gresource.xml" });
    const res = b.addInstallBinFile(b.path("resources/resources.gresource"), "resources.gresource");
    const desktop = b.addInstallBinFile(b.path("resources/com.github.TeamPuzel.Crates.desktop"), "com.github.TeamPuzel.Crates.desktop");
    const icon = b.addInstallBinFile(b.path("resources/cargo.svg"), "com.github.TeamPuzel.Crates.svg");
    
    if (dev_install) {
        _ = b.run(&.{ "sh", "-c", "cd resources; cp ./cargo.svg ~/.icons/com.github.TeamPuzel.Crates.svg" });
        _ = b.run(&.{ "sh", "-c", "sudo desktop-file-install resources/com.github.TeamPuzel.Crates.desktop" });
    }
    
    b.installArtifact(exe);
    
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.setCwd(b.path("zig-out/bin"));
    run_cmd.step.dependOn(b.getInstallStep());
    
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&res.step);
    run_step.dependOn(&desktop.step);
    run_step.dependOn(&icon.step);
    run_step.dependOn(&run_cmd.step);
    
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
