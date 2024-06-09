const std = @import("std");

const suggested_version = "0.2.0";
const id = "com.github.TeamPuzel.Crates";

pub fn build(b: *std.Build) !void {
    const stable = b.option(bool, "stable", "Configure the application to the stable appearance") orelse false;
    const build_id = b.option(u16, "build-id", "Manually specify a value") orelse std.crypto.random.int(u16);
    const version = b.option([]const u8, "version", "Manually specify a value") orelse suggested_version;
    
    const options = b.addOptions();
    options.addOption(bool, "stable", stable);
    options.addOption(u16, "build_id", build_id);
    options.addOption([]const u8, "version", version);
    
    // MARK: - Resources -----------------------------------------------------------------------------------------------
    
    const icon_step = try prepareIconBundleStep(b);
    
    const compile_icons_step = b.addSystemCommand(&.{ "sh", "-c", "glib-compile-resources resources.gresource.xml" });
    compile_icons_step.setCwd(icon_step.getDirectory());
    compile_icons_step.step.dependOn(&icon_step.step);
    
    const copy_icon_resource_step = b.addInstallFile(icon_step.getDirectory().path(b, "resources.gresource"), "resources.gresource");
    copy_icon_resource_step.dir = .bin;
    copy_icon_resource_step.step.dependOn(&compile_icons_step.step);
    
    // Copy top-level resources
    const resource_install_step = b.addInstallFile(b.path("resources/cargo.svg"), id ++ ".svg");
    resource_install_step.dir = .bin;
    
    const desktop_file_write_step = b.addWriteFile(id ++ ".desktop", try generateDesktopFileForRelease(b, version));
    const desktop_file_install_step = b.addInstallFile(desktop_file_write_step.getDirectory().path(b, id ++ ".desktop"), id ++ ".desktop");
    desktop_file_install_step.step.dependOn(&desktop_file_write_step.step);
    desktop_file_install_step.dir = .bin;
    
    // MARK: - Local build ---------------------------------------------------------------------------------------------
    // This defines a normal build and doesn't bundle anything.
    
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
    
    exe.step.dependOn(&resource_install_step.step);
    exe.step.dependOn(&copy_icon_resource_step.step);
    exe.step.dependOn(&desktop_file_install_step.step);
    
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
    
    exe.root_module.addOptions("config", options);
    
    b.installArtifact(exe); // TODO: Improve
    
    // MARK: - Running -------------------------------------------------------------------------------------------------
    
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.setCwd(b.path("zig-out/bin"));
    run_cmd.step.dependOn(b.getInstallStep());
    
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    // run_step.dependOn(&resource_install_step.step);
    
    // MARK: - Testing -------------------------------------------------------------------------------------------------
    // There are no unit tests at the moment as basically all the code is just UI or trivial.
    
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    
    // MARK: - Flatpak -------------------------------------------------------------------------------------------------
    // TODO: aarch64 cross compilation
    const x86_64 = b.addExecutable(.{
        .name = "crates",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(try std.Build.parseTargetQuery(.{ .arch_os_abi = "x86_64-linux-gnu" })),
        .optimize = .ReleaseSmall
    });
    x86_64.linkLibC();
    x86_64.linkSystemLibrary2("libadwaita-1", .{ .preferred_link_mode = .dynamic, .weak = true });
    x86_64.addLibraryPath(b.path("cross/x86_64/merged/usr/lib64"));
    x86_64.addIncludePath(b.path("cross/x86_64/merged/usr/include"));
    x86_64.root_module.addOptions("config", options);
    
    const x86_64_artifact = b.addInstallArtifact(x86_64, .{ .dest_dir = .{ .override = .{ .custom = "x86_64" } } });
    
    const bundle_step = b.step("bundle", "Generate a bundle and flatpak manifest for a GitHub release");
    bundle_step.dependOn(&x86_64_artifact.step);
    bundle_step.dependOn(&resource_install_step.step);
    // const x86_64_compress = b.addSystemCommand(&.{ "tar" });
    
    // const metainfo_install_step = b.addWriteFile(id ++ ".metainfo.xml", try generateMetaInfoForRelease(b));
    // TODO: This step depends on the sha256 of the bundle and needs to be completed last.
    // const flatpak_manifest_install_step = b.addWriteFile(id ++ ".yml", try generateFlatpakManifestForRelease(b, version, "todo", "todo"));
}

fn prepareIconBundleStep(b: *std.Build) !*std.Build.Step.WriteFile {
    const icon_step = b.addWriteFiles();
    _ = icon_step.addCopyDirectory(b.path("resources/icons"), "", .{});
    
    var manifest = std.ArrayList(u8).init(b.allocator);
    try manifest.appendSlice("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
    try manifest.appendSlice("<gresources>");
    try manifest.appendSlice("<gresource prefix=\"/com/github/teampuzel/icons/scalable/actions/\">");
    
    const dir = try std.fs.openDirAbsolute(b.path("resources/icons").getPath(b), .{ .iterate = true });
    var iter = dir.iterate();
    while (try iter.next()) |file| {
        try manifest.appendSlice(try std.fmt.allocPrint(
            b.allocator,
            "<file preprocess=\"xml-stripblanks\">{s}</file>",
            .{ file.name }
        ));
    }
    
    try manifest.appendSlice("</gresource>");
    try manifest.appendSlice("</gresources>");
    
    _ = icon_step.add("resources.gresource.xml", manifest.items);
    
    return icon_step;
}

fn generateFlatpakManifestForRelease(
    b: *std.Build,
    version: []const u8,
    sha_x86_64: []const u8,
    sha_aarch64: []const u8
) ![]const u8 {
    return try std.fmt.allocPrint(
        b.allocator,
        \\id: {s}
        \\runtime: org.gnome.Platform
        \\runtime-version: '46'
        \\sdk: org.gnome.Sdk
        \\command: crates
        \\
        \\finish-args:
        \\- --socket=wayland
        \\- --share=ipc
        \\- --socket=fallback-x11
        \\- --share=network
        \\
        \\modules:
        \\- name: crates
        \\    buildsystem: simple
        \\    build-commands:
        \\    - tar -xf ./crates.tar.xz
        \\    - install -Dm644 ${{FLATPAK_ID}}.metainfo.xml ${{FLATPAK_DEST}}/share/metainfo/${{FLATPAK_ID}}.metainfo.xml
        \\    - install -Dm644 ${{FLATPAK_ID}}.svg ${{FLATPAK_DEST}}/share/icons/hicolor/scalable/apps/${{FLATPAK_ID}}.svg
        \\    - install -Dm644 ${{FLATPAK_ID}}.desktop ${{FLATPAK_DEST}}/share/applications/${{FLATPAK_ID}}.desktop
        \\    - install -Dm755 crates ${{FLATPAK_DEST}}/bin/crates
        \\    sources:
        \\    - type: file
        \\        dest-filename: crates.tar.xz
        \\        url: https://github.com/TeamPuzel/Crates/releases/download/{s}/crates-x86_64.tar.xz
        \\        sha256: TODO
        \\        only-arches:
        \\        - x86_64
        \\    - type: file
        \\        dest-filename: crates.tar.xz
        \\        url: https://github.com/TeamPuzel/Crates/releases/download/{s}/crates-aarch64.tar.xz
        \\        sha256: TODO
        \\        only-arches:
        \\        - aarch64
        ,
        .{ id, version, sha_x86_64, version, sha_aarch64 }
    );
}

fn generateDesktopFileForRelease(b: *std.Build, version: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(
        b.allocator,
        \\[Desktop Entry]
        \\Version={s}
        \\Name=Crates
        \\Comment=A graphical search interface for Rust crates
        \\Categories=Development;GNOME;
        \\Icon={s}
        \\Keywords=rust;crate;package;
        \\Terminal=false
        \\Type=Application
        \\Exec=crates
        ,
        .{ version, id }
    );
}

fn generateMetaInfoForRelease(b: *std.Build) ![]const u8 {
    return try std.fmt.allocPrint(
        b.allocator,
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<component type="desktop-application">
        \\<id>{s}</id>
        \\
        \\<name>Crates</name>
        \\<summary>A graphical search interface for Rust crates</summary>
        \\
        \\<metadata_license>CC-BY-4.0</metadata_license>
        \\<project_license>GPL-3.0-or-later</project_license>
        \\
        \\<supports>
        \\    <control>pointing</control>
        \\    <control>keyboard</control>
        \\    <control>touch</control>
        \\</supports>
        \\
        \\<description>
        \\    <p>
        \\    Crates is a minimal application for browsing Rust crates from crates.io and/or custom sources.
        \\    </p>
        \\</description>
        \\
        \\<launchable type="desktop-id">com.github.TeamPuzel.Crates.desktop</launchable>
        \\<screenshots>
        \\    <screenshot type="default">
        \\    <image>https://github.com/TeamPuzel/Crates/assets/94306330/4a2bb43e-1dd2-4fbe-be94-41dff84d3983</image>
        \\    </screenshot>
        \\    <screenshot>
        \\    <image>https://github.com/TeamPuzel/Crates/assets/94306330/db274838-187f-457a-86b2-ae8d436fef15</image>
        \\    </screenshot>
        \\</screenshots>
        \\</component>
        ,
        .{ id }
    );
}