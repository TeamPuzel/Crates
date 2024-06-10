const std = @import("std");

const suggested_version = "0.2.0";
const id = "com.github.TeamPuzel.Crates";

const bundle_targets: []const std.Target.Query = &.{
    std.Target.Query { .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    std.Target.Query { .cpu_arch = .x86_64,  .os_tag = .linux, .abi = .gnu }
};

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
            exe.addLibraryPath(b.path("cross/x86_64/usr/lib64"));
            exe.addIncludePath(b.path("cross/x86_64/usr/include"));
        } else if (target.result.cpu.arch == .aarch64) {
            exe.addLibraryPath(b.path("cross/aarch64/usr/lib64"));
            exe.addIncludePath(b.path("cross/aarch64/usr/include"));
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
    
    var manifest = b.addWriteFile(id ++ ".yml", try generateFlatpakManifestForRelease(b));
    var manifest_steps = std.ArrayList(*ManifestSourceDerive).init(b.allocator);
    
    const bundle_step = b.step("bundle", "Generate a bundle and flatpak manifest for a GitHub release");
    
    for (bundle_targets) |bundle_target| {
        const bundle_exe = b.addExecutable(.{
            .name = "crates",
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(bundle_target),
            .optimize = .ReleaseSmall
        });
        bundle_exe.linkLibC();
        bundle_exe.linkSystemLibrary2("libadwaita-1", .{ .preferred_link_mode = .dynamic, .weak = true });
        bundle_exe.addLibraryPath(b.path(
            try std.fmt.allocPrint(b.allocator, "cross/{s}/usr/lib64", .{ @tagName(bundle_target.cpu_arch.?) })
        ));
        bundle_exe.addIncludePath(b.path(
            try std.fmt.allocPrint(b.allocator, "cross/{s}/usr/include", .{ @tagName(bundle_target.cpu_arch.?) })
        ));
        bundle_exe.root_module.addOptions("config", options);
        
        const artifact = b.addInstallArtifact(bundle_exe, .{ .dest_dir = .{
            .override = .{ .custom = @tagName(bundle_target.cpu_arch.?) }
        } });
        
        const archive_dir = b.addWriteFiles();
        _ = archive_dir.addCopyFile(artifact.emitted_bin.?, "crates");
        _ = archive_dir.add(id ++ ".metainfo.xml", try generateMetaInfoForRelease(b));
        _ = archive_dir.add(id ++ ".desktop", try generateDesktopFileForRelease(b, version));
        
        _ = archive_dir.addCopyFile(icon_step.getDirectory().path(b, "resources.gresource"), "resources.gresource");
        archive_dir.step.dependOn(&compile_icons_step.step);
        
        _ = archive_dir.addCopyFile(b.path("resources/cargo.svg"), id ++ ".svg");
        
        const compress_step = b.addSystemCommand(&.{
            "sh", "-c",
            try std.fmt.allocPrint(
                b.allocator,
                "tar cfJ crates-{s}.tar.xz *",
                .{ @tagName(bundle_target.cpu_arch.?) }
            )
        });
        compress_step.step.dependOn(&archive_dir.step);
        compress_step.setCwd(archive_dir.getDirectory());
        
        const checksum_step = b.addSystemCommand(&.{
            "sh", "-c",
            try std.fmt.allocPrint(
                b.allocator,
                "sha256sum crates-{s}.tar.xz",
                .{ @tagName(bundle_target.cpu_arch.?) }
            )
        });
        checksum_step.step.dependOn(&compress_step.step);
        checksum_step.setCwd(archive_dir.getDirectory());
        const stdout = checksum_step.captureStdOut();
        const manifest_source_step = ManifestSourceDerive.init(
            b, manifest.getDirectory().path(b, id ++ ".yml"), stdout, version, @tagName(bundle_target.cpu_arch.?)
        );
        manifest_source_step.step.dependOn(&checksum_step.step);
        manifest_source_step.step.dependOn(&manifest.step);
        try manifest_steps.append(manifest_source_step);
        
        const archive_name = try std.fmt.allocPrint(b.allocator, "crates-{s}.tar.xz", .{ @tagName(bundle_target.cpu_arch.?) });
        
        const install_step = b.addInstallFile(
            archive_dir.getDirectory().path(b, archive_name),
            archive_name
        );
        install_step.step.dependOn(&compress_step.step);
        install_step.dir = .{ .custom = "bundle" };
        
        bundle_step.dependOn(&install_step.step);
    }
    
    const install_manifest = b.addInstallFile(manifest.getDirectory().path(b, id ++ ".yml"), id ++ ".yml");
    for (manifest_steps.items) |step| install_manifest.step.dependOn(&step.step);
    install_manifest.dir = .{ .custom = "bundle" };
    
    bundle_step.dependOn(&install_manifest.step);
}

const ManifestSourceDerive = struct {
    step: std.Build.Step,
    version: []const u8,
    arch: []const u8,
    manifest: std.Build.LazyPath,
    sha256: std.Build.LazyPath,

    fn init(
        b: *std.Build,
        manifest: std.Build.LazyPath,
        sha256: std.Build.LazyPath,
        version: []const u8,
        arch: []const u8
    ) *ManifestSourceDerive {
        const self = b.allocator.create(ManifestSourceDerive) catch unreachable;
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "ManifestSourceDeriveStep",
                .owner = b,
                .makeFn = make
            }),
            .manifest = manifest,
            .sha256 = sha256,
            .version = version,
            .arch = arch
        };
        return self;
    }
    
    fn make(step: *std.Build.Step, _: std.Progress.Node) anyerror!void {
        const self: *ManifestSourceDerive = @fieldParentPtr("step", step);
        
        const sha_raw = try std.fs.openFileAbsolute(self.sha256.getPath(self.step.owner), .{});
        const sha = try sha_raw.readToEndAlloc(self.step.owner.allocator, std.math.maxInt(usize));
        
        const man = try std.fs.openFileAbsolute(self.manifest.getPath(self.step.owner), .{ .lock = .exclusive, .mode = .read_write });
        defer man.close();
        
        try man.seekTo(try man.getEndPos());
        
        try man.writeAll(try generateFlatpakManifestSourceForRelease(
            self.step.owner,
            self.version,
            std.mem.sliceTo(sha, ' '),
            self.arch
        ));
    }
};

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

fn generateFlatpakManifestForRelease(b: *std.Build) ![]const u8 {
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
        \\    - install -Dm644 resources.gresource ${{FLATPAK_DEST}}/bin/resources.gresource
        \\    - install -Dm755 crates ${{FLATPAK_DEST}}/bin/crates
        \\    sources:
        \\
        ,
        .{ id }
    );
}

fn generateFlatpakManifestSourceForRelease(
    b: *std.Build,
    version: []const u8,
    sha256: []const u8,
    arch: []const u8
) ![]const u8 {
    return try std.fmt.allocPrint(
        b.allocator,
        \\    - type: file
        \\        dest-filename: crates.tar.xz
        \\        url: https://github.com/TeamPuzel/Crates/releases/download/{s}/crates-{s}.tar.xz
        \\        sha256: {s}
        \\        only-arches:
        \\        - {s}
        \\
        ,
        .{ version, arch, sha256, arch }
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