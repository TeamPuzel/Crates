const std = @import("std");
const c = @cImport({
    @cInclude("libadwaita-1/adwaita.h");
});

const api = @import("api.zig");
// const resources: [*:0]const u8 align(4) = @embedFile("resources");

var app: *anyopaque = undefined;
var window: *c.GtkWidget = undefined;

pub fn main() !void {
    app = c.g_object_new(
        c.adw_application_get_type(),
        "application-id", "com.github.TeamPuzel.Crates",
        c.NULL
    ) orelse return error.CreatingApplication;
    defer c.g_object_unref(app);
    
    _ = c.g_signal_connect_data(@ptrCast(app), "activate", activate, null, null, 0);
    
    _ = c.g_application_run(@alignCast(@ptrCast(app)), @intCast(std.os.argv.len), @ptrCast(std.os.argv.ptr));
}

fn activate() callconv(.C) void {
    window = c.adw_application_window_new(@alignCast(@ptrCast(app)));
    c.gtk_window_set_title(@ptrCast(window), "Crates");
    c.gtk_window_set_default_size(@ptrCast(window), 800, 600);
    c.gtk_widget_set_size_request(window, 400, 300);
    
    var icon_res_err: [*c]c.GError = null;
    const icon_resource = c.g_resource_load("/home/lua/Projects/adwaita-test/zig-out/bin/resources.gresource", &icon_res_err) orelse {
        std.debug.panic("{s}", .{ icon_res_err.*.message });
    };
    c.g_resources_register(icon_resource);
    const icon_theme = c.gtk_icon_theme_get_for_display(c.gdk_display_get_default());
    c.gtk_icon_theme_add_resource_path(icon_theme, "/com/github/teampuzel/icons");
    
    // std.debug.print("{s}", .{ api.get("rand", 1, std.heap.c_allocator) catch |err| std.debug.panic("{!}", .{ err }) });
    
    const about_action = c.g_simple_action_new("about", null);
    _ = c.g_signal_connect_data(about_action, "activate", about, null, null, 0);
    c.g_action_map_add_action(@ptrCast(window), @ptrCast(about_action));
    
    const main_menu = c.g_menu_new();
    c.g_menu_append(main_menu, "About Crates", "win.about");
    
    const main_menu_button = c.gtk_menu_button_new();
    c.gtk_menu_button_set_icon_name(@ptrCast(main_menu_button), "open-menu-symbolic");
    c.gtk_widget_set_tooltip_text(main_menu_button, "Main Menu");
    c.gtk_menu_button_set_menu_model(@ptrCast(main_menu_button), @alignCast(@ptrCast(main_menu)));
    
    const search_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0);
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(search_box), "linked");
    
    const source_button = c.gtk_button_new();
    c.gtk_button_set_icon_name(@ptrCast(source_button), "search-global-symbolic");
    c.gtk_widget_set_tooltip_text(source_button, "Source");
    
    const search_entry = c.gtk_search_entry_new();
    c.gtk_search_entry_set_placeholder_text(@ptrCast(search_entry), "Search crates.io");
    _ = c.g_signal_connect_data(search_entry, "activate", @ptrCast(&searchSubmit), null, null, 0);
    
    c.gtk_box_append(@ptrCast(search_box), search_entry);
    c.gtk_box_append(@ptrCast(search_box), source_button);
    
    const toolbar_view = c.adw_toolbar_view_new();
    
    const header = c.adw_header_bar_new();
    c.adw_header_bar_pack_start(@ptrCast(header), search_box);
    c.adw_header_bar_pack_end(@ptrCast(header), main_menu_button);
    c.adw_toolbar_view_add_top_bar(@ptrCast(toolbar_view), header);
    
    // const content = c.gtk_list_box_new();
    // const row = c.adw_action_row_new();
    // c.adw_preferences_row_set_title(@ptrCast(row), "Rand");
    // c.adw_action_row_set_subtitle(@ptrCast(row), "A crate that does stuff");
    // c.gtk_list_box_append(@ptrCast(content), row);
    
    // c.adw_toolbar_view_set_content(@ptrCast(toolbar_view), content);
    
    const placeholder_label = c.gtk_label_new("No search query");
    c.gtk_widget_set_hexpand(placeholder_label, 0);
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(placeholder_label), "title-4");
    
    c.adw_toolbar_view_set_content(@ptrCast(toolbar_view), placeholder_label);
    
    c.adw_application_window_set_content(@ptrCast(window), toolbar_view);
    c.gtk_window_present(@ptrCast(window));
    c.gtk_window_set_focus(@ptrCast(window), null);
}

fn searchSubmit(self: *c.GtkSearchEntry) callconv(.C) void {
    const query = c.gtk_editable_get_text(@ptrCast(self));
    const slice = std.mem.span(query);
    std.debug.print("{s}", .{ api.get(slice, 1, std.heap.c_allocator) catch |err| std.debug.panic("{!}", .{ err }) });
}

fn about() callconv(.C) void {
    const developers = [_:0][*c]const u8 {
        &"TeamPuzel (Lua)".*
    };

    const designers = [_:0][*c]const u8 {
        &"TeamPuzel (Lua)".*
    };
    
    c.adw_show_about_window(
        @ptrCast(window),
        "application-name", "Crates",
        "developer-name", "TeamPuzel (Lua)",
        // "application-icon", "com.github.TeamPuzel.Crates",
        "version", "1.0.0",
        "copyright", "© 2024 TeamPuzel (Lua)",
        "issue-url", "https://github.com/TeamPuzel/Crates/issues/new",
        "website", "https://github.com/TeamPuzel/Crates",
        "license-type", c.GTK_LICENSE_GPL_3_0,
        "developers", &developers,
        "designers", &designers,
        c.NULL
    );
}

fn shortcuts() callconv(.C) void {
    
}
