const std = @import("std");
const config = @import("config");
const objc = @import("objc");

const AutoReleasePool = objc.AutoReleasePool;
const AnyInstance = objc.AnyInstance;
const nil = objc.nil;

const foundation = objc.foundation;
const cocoa = objc.cocoa;

const NSString = foundation.NSString;
const NSStr = foundation.NSStr;
const NSNotification = foundation.NSNotification;
const NSApplication = cocoa.NSApplication;
const NSWindow = cocoa.NSWindow;
const NSMenu = cocoa.NSMenu;
const NSMenuItem = cocoa.NSMenuItem;

pub fn main() !noreturn {
    registerClasses();
    
    const autoreleasepool = AutoReleasePool.push();
    defer autoreleasepool.pop();
    
    const nsapp = NSApplication.sharedApplication();
    _ = nsapp.setActivationPolicy(.regular);
    nsapp.setDelegate(CratesApplicationDelegate.alloc().autorelease().any);
    nsapp.run();
}

fn registerClasses() void {
    // Automatic registration is currently not implementable and does nothing
    objc.autoRegisterClass(CratesApplicationDelegate);
    objc.autoRegisterClass(CratesWindowDelegate);
    
    const NSObject = objc.AnyClass.named("NSObject");
    
    const ImplCratesApplicationDelegate = objc.AnyClass.new("CratesApplicationDelegate", NSObject);
    defer ImplCratesApplicationDelegate.register();
    _ = ImplCratesApplicationDelegate.method("applicationDidFinishLaunching:", "@:@", CratesApplicationDelegate.applicationDidFinishLaunching);
    _ = ImplCratesApplicationDelegate.method("applicationShouldTerminateAfterLastWindowClosed:", "@:@", CratesApplicationDelegate.applicationShouldTerminateAfterLastWindowClosed);
    _ = ImplCratesApplicationDelegate.method("applicationWillTerminate:", "@:@", CratesApplicationDelegate.applicationWillTerminate);
    
    const ImplCratesWindowDelegate = objc.AnyClass.new("CratesWindowDelegate", NSObject);
    defer ImplCratesWindowDelegate.register();
    _ = ImplCratesWindowDelegate.method("windowWillClose:", "@:@", CratesWindowDelegate.windowWillClose);
}

const CratesApplicationDelegate = packed struct { usingnamespace objc.foundation.NSObjectDerive(Self); const Self = @This();
    any: AnyInstance,
    
    fn applicationShouldTerminateAfterLastWindowClosed(_: Self, _: objc.Selector, _: AnyInstance) callconv(.C) bool { return true; }
    
    fn applicationWillTerminate(_: Self, _: objc.Selector, _: AnyInstance) callconv(.C) void {
        
    }
    
    fn applicationDidFinishLaunching(self: Self, _: objc.Selector, _: AnyInstance) callconv(.C) void {
        const nsapp = NSApplication.sharedApplication();
        
        const main_menu = nsapp.mainMenu();
        
        const window_menu_item = NSMenuItem.alloc().init().autorelease();
        window_menu_item.setTitle(NSStr("Window"));
        
        const window_menu = NSMenu.alloc().init().autorelease();
        window_menu_item.setSubmenu(window_menu);
        nsapp.setWindowsMenu(window_menu);
        
        main_menu.addItem(window_menu_item);
        
        const help_menu_item = NSMenuItem.alloc().init().autorelease();
        help_menu_item.setTitle(NSStr("Help"));
        const help_menu = NSMenu.alloc().init().autorelease();
        help_menu_item.setSubmenu(help_menu);
        nsapp.setHelpMenu(help_menu);
        
        main_menu.addItem(help_menu_item);
        
        const nswindow = NSWindow.alloc().initWithContentRect_styleMask_backing_defer(
            .{ .x = 0, .y = 0, .w = 800, .h = 600 }, .{}, .buffered, false
        );
        nswindow.setMinSize(.{ .w = 400, .h = 500 });
        if (!nswindow.setFrameUsingName(NSStr("CratesApplicationWindow"))) nswindow.center();
        
        _ = nswindow.setFrameAutosaveName(NSStr("CratesApplicationWindow"));
        
        nswindow.setDelegate(CratesWindowDelegate.alloc().init().autorelease().any);
        nswindow.setTitle(NSStr("Crates"));
        
        nsapp.activateIgnoringOtherApps(true);
        nswindow.makeKeyAndOrderFront(self.any);
    }
};

const CratesWindowDelegate = packed struct { usingnamespace objc.foundation.NSObjectDerive(Self); const Self = @This();
    any: AnyInstance,
    
    fn windowWillClose(_: AnyInstance, _: objc.Selector, notification: NSNotification) callconv(.C) void {
        notification.object().as(NSWindow).saveFrameUsingName(NSStr("CratesApplicationWindow"));
    }
};
