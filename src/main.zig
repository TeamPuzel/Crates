const std = @import("std");
const c = @cImport({
    @cInclude("libadwaita-1/adwaita.h");
});

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
    // c.gtk_widget_set_size_request(window, 800, 600);
    
    const about_action = c.g_simple_action_new("about", null);
    _ = c.g_signal_connect_data(about_action, "activate", about, null, null, 0);
    c.g_action_map_add_action(@ptrCast(window), @ptrCast(about_action));
    
    const main_menu = c.g_menu_new();
    c.g_menu_append(main_menu, "About Crates", "win.about");
    
    const main_menu_button = c.gtk_menu_button_new();
    c.gtk_menu_button_set_icon_name(@ptrCast(main_menu_button), "open-menu-symbolic");
    c.gtk_widget_set_tooltip_text(main_menu_button, "Main Menu");
    c.gtk_menu_button_set_menu_model(@ptrCast(main_menu_button), @alignCast(@ptrCast(main_menu)));
    
    const toolbar_view = c.adw_toolbar_view_new();
    
    const header = c.adw_header_bar_new();
    c.adw_header_bar_pack_end(@ptrCast(header), main_menu_button);
    c.adw_toolbar_view_add_top_bar(@ptrCast(toolbar_view), header);
    
    c.adw_application_window_set_content(@ptrCast(window), toolbar_view);
    
    c.gtk_window_present(@ptrCast(window));
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