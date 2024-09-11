const std = @import("std");

const suggested_version = "0.4.0";
const id = "com.github.TeamPuzel.Crates";

const bundle_targets: []const std.Target.Query = &.{
    std.Target.Query { .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    std.Target.Query { .cpu_arch = .x86_64,  .os_tag = .linux, .abi = .gnu }
};

pub fn build(b: *std.Build) !void {
    const standard_target = b.standardTargetOptions(.{});
    const standard_optimize = b.standardOptimizeOption(.{});
    
    const stable = b.option(bool, "stable", "Configure the application to the stable appearance") orelse false;
    const build_id = b.option(u16, "build-id", "Manually specify a value") orelse std.crypto.random.int(u16);
    const version = b.option([]const u8, "version", "Manually specify a value") orelse suggested_version;
    
    const config = b.addOptions();
    config.addOption(bool, "stable", stable);
    config.addOption(u16, "build_id", build_id);
    config.addOption([]const u8, "version", version);
    
    // MARK: - Shared code ---------------------------------------------------------------------------------------------
    
    const shared = b.createModule(.{
        .root_source_file = b.path("src/shared/root.zig")
    });
    
    const objc = b.dependency("objc", .{
        .target = standard_target,
        .optimize = standard_optimize
    });
    
    // MARK: - Local Cocoa build ---------------------------------------------------------------------------------------
    
    const cocoa_exe = b.addExecutable(.{
        .name = "Crates",
        .root_source_file = b.path("src/cocoa/main.zig"),
        .target = standard_target,
        .optimize = standard_optimize
    });
    cocoa_exe.root_module.addImport("shared", shared);
    cocoa_exe.root_module.addOptions("config", config);
    cocoa_exe.root_module.addImport("objc", objc.module("objc"));
    
    const cocoa_run = b.addRunArtifact(cocoa_exe);
    cocoa_run.step.dependOn(&cocoa_exe.step);
    
    if (b.args) |args| cocoa_run.addArgs(args);
    
    const cocoa_run_step = b.step("run-cocoa", "Run using the native Cocoa frontend");
    cocoa_run_step.dependOn(&cocoa_run.step);
    
    // MARK: - GNOME Resources -----------------------------------------------------------------------------------------
    
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
    
    const desktop_file_write_step = b.addWriteFile(id ++ ".desktop", try generateDesktopFileForRelease(b));
    const desktop_file_install_step = b.addInstallFile(desktop_file_write_step.getDirectory().path(b, id ++ ".desktop"), id ++ ".desktop");
    desktop_file_install_step.step.dependOn(&desktop_file_write_step.step);
    desktop_file_install_step.dir = .bin;
    
    // MARK: - Local Adwaita build -------------------------------------------------------------------------------------
    // This defines a normal build and doesn't bundle anything.
    
    const gnome_exe = b.addExecutable(.{
        .name = "crates",
        .root_source_file = b.path("src/gnome/main.zig"),
        .target = standard_target,
        .optimize = standard_optimize
    });
    gnome_exe.linkLibC();
    gnome_exe.linkSystemLibrary2("libadwaita-1", .{ .preferred_link_mode = .dynamic, .weak = true });
    gnome_exe.root_module.addImport("shared", shared);
    gnome_exe.root_module.addOptions("config", config);
    
    gnome_exe.step.dependOn(&resource_install_step.step);
    gnome_exe.step.dependOn(&copy_icon_resource_step.step);
    gnome_exe.step.dependOn(&desktop_file_install_step.step);
    
    // When cross compiling architecture specific libraries are needed.
    // While surprisingly no distribution I use allows conveniently downloading those, it is fairly easy
    // to do so using a container (if a bit wasteful).
    // TODO: Write a program/script to download cross compilation libraries from a distribution's mirror.
    if (standard_target.result.os.tag == .macos and standard_target.query.isNative()) {
        gnome_exe.root_module.addImport("objc", objc.module("objc"));
        gnome_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/libadwaita/1.5.0/lib" });
        gnome_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/gtk4/4.14.4/lib" });
        gnome_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/pango/1.52.2/lib" });
        gnome_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/harfbuzz/8.5.0/lib" });
        gnome_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/gdk-pixbuf/2.42.12/lib" });
        gnome_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/cairo/1.18.0/lib" });
        gnome_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/graphene/1.10.8/lib" });
        gnome_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/Cellar/glib/2.80.2/lib" });
        gnome_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/gettext/lib" });
        gnome_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/Cellar/libadwaita/1.5.0/include" });
    } else if (standard_target.query.isNative()) {
        gnome_exe.addLibraryPath(.{ .cwd_relative = "/usr/lib64" });
        gnome_exe.addIncludePath(.{ .cwd_relative = "/usr/include" });
    } else {
        gnome_exe.addLibraryPath(b.path(
            try std.fmt.allocPrint(b.allocator, "cross/{s}/usr/lib64", .{ @tagName(standard_target.result.cpu.arch) })
        ));
        gnome_exe.addIncludePath(b.path(
            try std.fmt.allocPrint(b.allocator, "cross/{s}/usr/include", .{ @tagName(standard_target.result.cpu.arch) })
        ));
    }
    
    b.installArtifact(gnome_exe); // TODO: Improve
    
    const gnome_run = b.addRunArtifact(gnome_exe);
    gnome_run.setCwd(b.path("zig-out/bin"));
    gnome_run.step.dependOn(b.getInstallStep());
    
    if (b.args) |args| gnome_run.addArgs(args);
    
    const gnome_run_step = b.step("run-gnome", "Run using the GNOME frontend");
    gnome_run_step.dependOn(&gnome_run.step);
    
    // MARK: - Running -------------------------------------------------------------------------------------------------
    
    const run_step = b.step("run", "Run the app using the default platform frontend");
    switch (standard_target.result.os.tag) {
        .macos => run_step.dependOn(&cocoa_run.step),
        else => run_step.dependOn(&gnome_run.step)
    }
    
    // MARK: - Testing -------------------------------------------------------------------------------------------------
    
    const shared_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/shared/root.zig"),
        .target = standard_target,
        .optimize = standard_optimize
    });
    
    const run_cocoa_unit_tests = b.addRunArtifact(shared_unit_tests);
    
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_cocoa_unit_tests.step);
    
    // MARK: - Flatpak -------------------------------------------------------------------------------------------------
    
    const manifest_dir = b.makeTempPath();
    const manifest_file = try std.fs.createFileAbsolute(try std.fmt.allocPrint(b.allocator, "{s}/" ++ id ++ ".yml", .{ manifest_dir }), .{});
    try manifest_file.writeAll(try generateFlatpakManifestForRelease(b));
    
    // var manifest = b.addWriteFile(id ++ ".yml", try generateFlatpakManifestForRelease(b));
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
        bundle_exe.root_module.addOptions("config", config);
        
        const archive_dir = b.addWriteFiles();
        _ = archive_dir.step.dependOn(&bundle_exe.step);
        _ = archive_dir.addCopyFile(bundle_exe.getEmittedBin(), "crates");
        _ = archive_dir.add(id ++ ".metainfo.xml", try generateMetaInfoForRelease(b));
        _ = archive_dir.add(id ++ ".desktop", try generateDesktopFileForRelease(b));
        
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
        checksum_step.has_side_effects = true;
        checksum_step.step.dependOn(&compress_step.step);
        checksum_step.setCwd(archive_dir.getDirectory());
        const stdout = checksum_step.captureStdOut();
        const manifest_source_step = ManifestSourceDerive.init(
            b, manifest_file, stdout, version, @tagName(bundle_target.cpu_arch.?)
        );
        manifest_source_step.step.dependOn(&checksum_step.step);
        // manifest_source_step.step.dependOn(&manifest.step);
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
    
    // const install_manifest = b.addInstallFile(manifest.getDirectory().path(b, id ++ ".yml"), id ++ ".yml");
    const install_manifest = b.addInstallFile(.{ .cwd_relative = try std.fmt.allocPrint(b.allocator, "{s}/" ++ id ++ ".yml", .{ manifest_dir }) }, id ++ ".yml");
    for (manifest_steps.items) |step| install_manifest.step.dependOn(&step.step);
    install_manifest.dir = .{ .custom = "bundle" };
    
    bundle_step.dependOn(&install_manifest.step);
}

const ManifestSourceDerive = struct {
    step: std.Build.Step,
    version: []const u8,
    arch: []const u8,
    manifest: std.fs.File,
    sha256: std.Build.LazyPath,

    fn init(
        b: *std.Build,
        manifest: std.fs.File,
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
        // manifest.addStepDependencies(&self.step);
        sha256.addStepDependencies(&self.step);
        return self;
    }
    
    fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
        const self: *ManifestSourceDerive = @fieldParentPtr("step", step);
        
        const sha_raw = try std.fs.openFileAbsolute(self.sha256.getPath(self.step.owner), .{});
        const sha = try sha_raw.readToEndAlloc(self.step.owner.allocator, std.math.maxInt(usize));
        
        // const man = try std.fs.openFileAbsolute(self.manifest.getPath(self.step.owner), .{ .lock = .exclusive, .mode = .write_only });
        // defer man.close();
        const man = self.manifest;
        
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
        \\  - --socket=wayland
        \\  - --share=ipc
        \\  - --socket=fallback-x11
        \\  - --share=network
        \\  - --device=dri
        \\
        \\modules:
        \\  - name: crates
        \\    buildsystem: simple
        \\    build-commands:
        \\      - tar -xf ./crates.tar.xz
        \\      - install -Dm644 ${{FLATPAK_ID}}.metainfo.xml ${{FLATPAK_DEST}}/share/metainfo/${{FLATPAK_ID}}.metainfo.xml
        \\      - install -Dm644 ${{FLATPAK_ID}}.svg ${{FLATPAK_DEST}}/share/icons/hicolor/scalable/apps/${{FLATPAK_ID}}.svg
        \\      - install -Dm644 ${{FLATPAK_ID}}.desktop ${{FLATPAK_DEST}}/share/applications/${{FLATPAK_ID}}.desktop
        \\      - install -Dm644 resources.gresource ${{FLATPAK_DEST}}/bin/resources.gresource
        \\      - install -Dm755 crates ${{FLATPAK_DEST}}/bin/crates
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
        \\      - type: file
        \\        dest-filename: crates.tar.xz
        \\        url: https://github.com/TeamPuzel/Crates/releases/download/{s}/crates-{s}.tar.xz
        \\        sha256: {s}
        \\        only-arches:
        \\          - {s}
        \\
        ,
        .{ version, arch, sha256, arch }
    );
}

fn generateDesktopFileForRelease(b: *std.Build) ![]const u8 {
    return try std.fmt.allocPrint(
        b.allocator,
        \\[Desktop Entry]
        \\Version=1.5
        \\Name=Crates
        \\Comment=A graphical search interface for Rust crates
        \\Categories=Development;GNOME;
        \\Icon={s}
        \\Keywords=rust;crate;package;
        \\Terminal=false
        \\Type=Application
        \\Exec=crates
        ,
        .{ id }
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
        \\    <image>https://github.com/TeamPuzel/Crates/assets/94306330/35086337-6524-4708-b6db-78506baf197e</image>
        \\    </screenshot>
        \\    <screenshot>
        \\    <image>https://github.com/TeamPuzel/Crates/assets/94306330/5d388d95-9e47-45a2-bcc7-51a9fe062e9e</image>
        \\    </screenshot>
        \\</screenshots>
        \\</component>
        ,
        .{ id }
    );
}
