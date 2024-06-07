const std = @import("std");
const c = @cImport({
    @cInclude("libadwaita-1/adwaita.h");
});

const api = @import("api.zig");

var app: *anyopaque = undefined;
var window: *c.GtkWidget = undefined;
var toolbar_view: *c.GtkWidget = undefined;
var search_entry: *c.GtkWidget = undefined;

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
    
    // Actions
    
    const about_action = c.g_simple_action_new("about", null);
    _ = c.g_signal_connect_data(about_action, "activate", about, null, null, 0);
    c.g_action_map_add_action(@ptrCast(window), @ptrCast(about_action));
    
    // Layout
    
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
    
    search_entry = c.gtk_search_entry_new();
    c.gtk_search_entry_set_placeholder_text(@ptrCast(search_entry), "Search crates.io");
    c.gtk_search_entry_set_search_delay(@ptrCast(search_entry), 1000);
    _ = c.g_signal_connect_data(search_entry, "search-changed", @ptrCast(&searchSubmit), null, null, 0);
    
    c.gtk_box_append(@ptrCast(search_box), search_entry);
    c.gtk_box_append(@ptrCast(search_box), source_button);
    
    toolbar_view = c.adw_toolbar_view_new();
    
    const header = c.adw_header_bar_new();
    c.adw_header_bar_pack_start(@ptrCast(header), search_box);
    c.adw_header_bar_pack_end(@ptrCast(header), main_menu_button);
    c.adw_toolbar_view_add_top_bar(@ptrCast(toolbar_view), header);
    
    const placeholder_label = c.gtk_label_new("No search query");
    c.gtk_widget_set_hexpand(placeholder_label, 0);
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(placeholder_label), "title-4");
    
    c.adw_toolbar_view_set_content(@ptrCast(toolbar_view), placeholder_label);
    
    c.adw_application_window_set_content(@ptrCast(window), toolbar_view);
    c.gtk_window_present(@ptrCast(window));
    c.gtk_window_set_focus(@ptrCast(window), null);
}

var current_page: usize = 1;

fn pageNext() callconv(.C) void {
    current_page += 1;
    searchSubmitKeepingPage(@ptrCast(search_entry));
}

fn pagePrev() callconv(.C) void {
    current_page -= 1;
    searchSubmitKeepingPage(@ptrCast(search_entry));
}

fn searchSubmit(self: *c.GtkSearchEntry) callconv(.C) void {
    current_page = 1;
    
    const query = c.gtk_editable_get_text(@ptrCast(self));
    const slice = std.mem.span(query);
    
    searchSubmitReal(slice);
}

fn searchSubmitKeepingPage(self: *c.GtkSearchEntry) callconv(.C) void {
    const query = c.gtk_editable_get_text(@ptrCast(self));
    const slice = std.mem.span(query);
    
    searchSubmitReal(slice);
}

fn searchSubmitReal(query: []const u8) void {
    if (query.len == 0) {
        const placeholder_label = c.gtk_label_new("No search query");
        c.gtk_widget_set_hexpand(placeholder_label, 0);
        c.gtk_style_context_add_class(c.gtk_widget_get_style_context(placeholder_label), "title-4");
        
        c.adw_toolbar_view_set_content(@ptrCast(toolbar_view), placeholder_label);
        // c.gtk_window_set_focus(@ptrCast(window), null);
        return;
    }
    
    const response = api.get(query, current_page, std.heap.c_allocator) catch |err| std.debug.panic("{!}", .{ err });
    
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    // defer arena.deinit(); // CRITICAL: MOVE THIS OUT OF THE FUNCTION, THE LIFETIME MUST OUTLIVE THE LIST UI
    const parsed = std.json.parseFromSliceLeaky(api.Search, arena.allocator(), response, .{ .ignore_unknown_fields = true }) catch unreachable;
    
    const content = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0);
    
    const header = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8);
    c.gtk_widget_set_halign(header, c.GTK_ALIGN_END);
    c.gtk_widget_set_size_request(header, -1, 24);
    c.gtk_widget_set_margin_bottom(header, 8);
    c.gtk_widget_set_margin_start(header, 16);
    c.gtk_widget_set_margin_end(header, 16);
    
    const result_count = c.gtk_label_new(
        std.fmt.allocPrintZ(arena.allocator(), "{d} results", .{ parsed.meta.total }) catch unreachable
    );
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(result_count), "dim-label");
    c.gtk_box_append(@ptrCast(header), result_count);
    
    c.gtk_box_append(@ptrCast(header), c.gtk_separator_new(c.GTK_ORIENTATION_HORIZONTAL));
    
    const total_pages = @divTrunc(parsed.meta.total, api.per_page) + 1;
    
    const page_label = c.gtk_label_new(
        std.fmt.allocPrintZ(arena.allocator(), "Page {d} of {d}", .{ current_page, total_pages }) catch unreachable
    );
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(page_label), "dim-label");
    c.gtk_box_append(@ptrCast(header), page_label);
    
    const navigation_buttons = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0);
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(navigation_buttons), "linked");
    
    const previous_page_button = c.gtk_button_new_from_icon_name("left-symbolic");
    c.gtk_widget_set_tooltip_text(previous_page_button, "Previous Page");
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(previous_page_button), "circular");
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(previous_page_button), "flat");
    _ = c.g_signal_connect_data(previous_page_button, "clicked", pagePrev, null, null, 0);
    c.gtk_box_append(@ptrCast(navigation_buttons), previous_page_button);
    const next_page_button = c.gtk_button_new_from_icon_name("right-symbolic");
    c.gtk_widget_set_tooltip_text(next_page_button, "Next Page");
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(next_page_button), "circular");
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(next_page_button), "flat");
    _ = c.g_signal_connect_data(next_page_button, "clicked", pageNext, null, null, 0);
    c.gtk_box_append(@ptrCast(navigation_buttons), next_page_button);
    
    if (current_page == 1) c.gtk_widget_set_sensitive(previous_page_button, 0);
    if (current_page == total_pages) c.gtk_widget_set_sensitive(next_page_button, 0);
    
    c.gtk_box_append(@ptrCast(header), navigation_buttons);
    
    const list_scroll_container = c.gtk_scrolled_window_new();
    c.gtk_widget_set_vexpand(list_scroll_container, 1);
    
    const list = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 8);
    c.gtk_widget_set_margin_top(list, 8);
    c.gtk_widget_set_margin_bottom(list, 32);
    c.gtk_widget_set_margin_start(list, 16);
    c.gtk_widget_set_margin_end(list, 16);
    
    for (parsed.crates) |crate| {
        const row = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 0);
        c.gtk_style_context_add_class(c.gtk_widget_get_style_context(row), "card");
        // c.gtk_widget_set_size_request(row, -1, 64);
        
        const row_header = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8);
        c.gtk_widget_set_size_request(row_header, -1, 32);
        c.gtk_widget_set_margin_start(row_header, 12);
        c.gtk_widget_set_margin_end(row_header, 12);
        
        const title_label = c.gtk_label_new(std.fmt.allocPrintZ(arena.allocator(), "<b><span>{s}</span></b>", .{ crate.name }) catch unreachable);
        c.gtk_label_set_use_markup(@ptrCast(title_label), 1);
        c.gtk_box_append(@ptrCast(row_header), title_label);
        const description_label = c.gtk_label_new(std.fmt.allocPrintZ(arena.allocator(), "{s}", .{ std.mem.sliceTo(crate.description.ptr, '\n') }) catch unreachable);
        c.gtk_label_set_ellipsize(@ptrCast(description_label), c.PANGO_ELLIPSIZE_END);
        c.gtk_style_context_add_class(c.gtk_widget_get_style_context(description_label), "dim-label");
        c.gtk_box_append(@ptrCast(row_header), description_label);
        
        c.gtk_box_append(@ptrCast(row), row_header);
        
        const row_detail = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 8);
        // c.gtk_style_context_add_class(c.gtk_widget_get_style_context(row_detail), "toolbar");
        // c.gtk_style_context_add_class(c.gtk_widget_get_style_context(row_detail), "linked");
        c.gtk_widget_set_size_request(row_detail, -1, 32);
        c.gtk_widget_set_margin_start(row_detail, 8);
        c.gtk_widget_set_margin_end(row_detail, 8);
        c.gtk_widget_set_margin_bottom(row_detail, 8);
        
        const website_button = c.gtk_button_new_from_icon_name("globe-symbolic");
        c.gtk_widget_set_tooltip_text(website_button, "Website");
        c.gtk_style_context_add_class(c.gtk_widget_get_style_context(website_button), "circular");
        c.gtk_box_append(@ptrCast(row_detail), website_button);
        const repo_button = c.gtk_button_new_from_icon_name("git-symbolic");
        c.gtk_widget_set_tooltip_text(repo_button, "Repository");
        c.gtk_style_context_add_class(c.gtk_widget_get_style_context(repo_button), "circular");
        c.gtk_box_append(@ptrCast(row_detail), repo_button);
        const more_button = c.gtk_button_new_from_icon_name("view-more-horizontal-symbolic");
        c.gtk_widget_set_tooltip_text(more_button, "More");
        c.gtk_style_context_add_class(c.gtk_widget_get_style_context(more_button), "circular");
        c.gtk_box_append(@ptrCast(row_detail), more_button);
        
        if (crate.homepage == null) c.gtk_widget_set_sensitive(website_button, 0)
        else _ = c.g_signal_connect_data(website_button, "clicked", @ptrCast(&openWebsiteForCrate), @constCast(@ptrCast(crate.homepage.?.ptr)), null, 0);
        if (crate.repository == null) c.gtk_widget_set_sensitive(repo_button, 0);
        
        c.gtk_box_append(@ptrCast(row), row_detail);
        
        c.gtk_box_append(@ptrCast(list), row);
    }
    
    const final_buttons = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0);
    c.gtk_style_context_add_class(c.gtk_widget_get_style_context(final_buttons), "linked");
    
    if (current_page > 1) {
        const previous_page_final_button = c.gtk_button_new_with_label("Previous Page");
        c.gtk_widget_set_hexpand(previous_page_final_button, 1);
        c.gtk_style_context_add_class(c.gtk_widget_get_style_context(previous_page_final_button), "pill");
        _ = c.g_signal_connect_data(previous_page_final_button, "clicked", pagePrev, null, null, 0);
        c.gtk_box_append(@ptrCast(final_buttons), previous_page_final_button);
    }
    if (current_page != total_pages) {
        const next_page_final_button = c.gtk_button_new_with_label("Next Page");
        c.gtk_widget_set_hexpand(next_page_final_button, 1);
        c.gtk_style_context_add_class(c.gtk_widget_get_style_context(next_page_final_button), "pill");
        c.gtk_style_context_add_class(c.gtk_widget_get_style_context(next_page_final_button), "suggested-action");
        _ = c.g_signal_connect_data(next_page_final_button, "clicked", pageNext, null, null, 0);
        c.gtk_box_append(@ptrCast(final_buttons), next_page_final_button);
    }
    
    c.gtk_box_append(@ptrCast(list), final_buttons);
    
    c.gtk_box_append(@ptrCast(content), header);
    c.gtk_scrolled_window_set_child(@ptrCast(list_scroll_container), list);
    c.gtk_box_append(@ptrCast(content), list_scroll_container);
    c.adw_toolbar_view_set_content(@ptrCast(toolbar_view), content);
    c.gtk_window_set_focus(@ptrCast(window), null);
}

fn openWebsiteForCrate(_: *c.GtkButton, addr: [*c]const u8) callconv(.C) void {
    c.gtk_show_uri(@ptrCast(window), addr, 0);
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
        "application-icon", "com.github.TeamPuzel.Crates",
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
