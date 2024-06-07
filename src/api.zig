const std = @import("std");
const c = @cImport({
    @cInclude("curl/curl.h");
});

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

var response_buf = std.ArrayList(u8).init(std.heap.c_allocator);

fn writeFunction(data: [*c]u8, size: usize, nmemb: usize, _: *anyopaque) callconv(.C) usize {
    for (0..size * nmemb) |i| response_buf.append(data[i]) catch |err| std.debug.panic("{!}", .{ err });
    return size * nmemb;
}

pub fn get(query: []const u8, page: usize, alloc: std.mem.Allocator) ![]u8 { 
    const curl = c.curl_easy_init() orelse return error.CurlInit;
    defer c.curl_easy_cleanup(curl);
    
    const url = try std.fmt.allocPrintZ(std.heap.c_allocator, std.fmt.comptimePrint("https://crates.io/api/v1/crates?per_page={d}", .{ per_page }) ++ "&q={s}&page={d}", .{ query, page });
    defer std.heap.c_allocator.free(url);
    
    _ = c.curl_easy_setopt(curl, c.CURLOPT_URL, url.ptr);
    _ = c.curl_easy_setopt(curl, c.CURLOPT_USERAGENT, "com.github.TeamPuzel.Crates/1.0.0");
    _ = c.curl_easy_setopt(curl, c.CURLOPT_WRITEFUNCTION, &writeFunction);
    
    _ = c.curl_easy_perform(curl);
    
    const ret = try alloc.alloc(u8, response_buf.items.len);
    std.mem.copyForwards(u8, ret, response_buf.items);
    response_buf.clearRetainingCapacity();
    return ret;
}