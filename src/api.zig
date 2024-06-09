const std = @import("std");

pub const per_page = 50;

pub const Search = struct {
    crates: []Crate,
    meta: struct {
        total: usize
    }
};

pub const Crate = struct {
    name: [:0]const u8,
    documentation: ?[:0]const u8,
    homepage: ?[:0]const u8,
    repository: ?[:0]const u8,
    max_version: [:0]const u8,
    max_stable_version: ?[:0]const u8,
    newest_version: [:0]const u8,
    downloads: usize,
    recent_downloads: usize,
    description: [:0]const u8
};

pub fn get(query: []const u8, page: usize, alloc: std.mem.Allocator) ![]u8 { 
    var client = std.http.Client { .allocator = alloc };
    defer client.deinit();
    
    const url = try std.fmt.allocPrintZ(
        alloc,
        std.fmt.comptimePrint("https://crates.io/api/v1/crates?per_page={d}", .{ per_page })
        ++ "&q={s}&page={d}",
        .{ query, page }
    );
    defer std.heap.c_allocator.free(url);
    
    var response = std.ArrayList(u8).init(alloc);
    
    _ = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .headers = .{
            .user_agent = .{ .override = "com.github.TeamPuzel.Crates/" ++ @import("root").version_string }
        },
        .response_storage = .{ .dynamic = &response }
    });
    
    return response.items;
}

// pub fn hasReadme(repo: []const u8) !bool {
    
// }

// pub fn getReadme(repo: []const u8) ![]const u8 {
    
// }
