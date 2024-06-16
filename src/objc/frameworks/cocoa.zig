const std = @import("std");
const objc = @import("../objc.zig");

const AnyInstance = objc.AnyInstance;

const foundation = objc.foundation;
const NSString = foundation.NSString;

pub const NSRect = extern struct { x: f64, y: f64, w: f64, h: f64 };
pub const NSSize = extern struct { w: f64, h: f64 };

pub const NSWindowStyleMask = packed struct (usize) {
    titled: bool = true,
    closable: bool = true,
    minimizable: bool = true,
    resizable: bool = true,
    _pad: u60 = 0
};

pub const NSBackingStoreType = enum (foundation.NSUInteger) {
    /// Deprecated
    retained,
    /// Deprecated
    nonretained,
    buffered
};

pub const NSApplicationActivationPolicy = enum (foundation.NSUInteger) {
    /// The application is an ordinary app that appears in the Dock and may have a user interface.
    regular,
    /// The application doesn’t appear in the Dock and doesn’t have a menu bar,
    /// but it may be activated programmatically or by clicking on one of its windows.
    accessory,
    /// The application doesn’t appear in the Dock and may not create windows or be activated.
    prohibited
};

pub const NSResponder = packed struct { pub usingnamespace NSResponderDerive(Self); const Self = @This();
    any: AnyInstance
};

pub fn NSResponderDerive(comptime Self: type) type {
    return packed struct { pub usingnamespace foundation.NSObjectDerive(Self);
        pub fn super() type { return NSResponder; }
        
        any: AnyInstance
    };
}

pub const NSApplication = packed struct { pub usingnamespace NSResponderDerive(Self); const Self = @This();
    any: AnyInstance,
    
    pub fn sharedApplication() Self {
        return Self.class().msg("sharedApplication", .{}, Self);
    }
    
    pub fn run(self: Self) noreturn {
        self.any.msg("run", .{}, noreturn);
    }
    
    pub fn setActivationPolicy(self: Self, policy: NSApplicationActivationPolicy) bool {
        return self.any.msg("setActivationPolicy:", .{ policy }, bool);
    }
    
    pub fn activate(self: Self) void {
        self.any.msg("activate", .{}, void);
    }
    
    pub fn activateIgnoringOtherApps(self: Self, ignore: bool) void {
        self.any.msg("activateIgnoringOtherApps:", .{ ignore }, void);
    }
    
    /// TODO: Correct the signature to use NSObject
    pub fn setDelegate(self: Self, delegate: AnyInstance) void {
        self.any.msg("setDelegate:", .{ delegate }, void);
    }
    
    pub fn mainMenu(self: Self) NSMenu {
        return self.any.msg("mainMenu", .{}, NSMenu);
    }
    
    pub fn setWindowsMenu(self: Self, menu: NSMenu) void {
        self.any.msg("setWindowsMenu:", .{ menu }, void);
    }
    
    pub fn setHelpMenu(self: Self, menu: NSMenu) void {
        self.any.msg("setHelpMenu:", .{ menu }, void);
    }
};

pub const NSWindow = packed struct { pub usingnamespace NSResponderDerive(Self); const Self = @This();
    any: AnyInstance,
    
    pub fn initWithContentRect_styleMask_backing_defer(
        self: Self, rect: NSRect, style: NSWindowStyleMask, backing: NSBackingStoreType, deferred: bool
    ) Self {
        return self.any.msg("initWithContentRect:styleMask:backing:defer:", .{ rect, style, backing, deferred }, Self);
    }
    
    pub fn setMinSize(self: Self, size: NSSize) void {
        self.any.msg("setMinSize:", .{ size }, void);
    }
    
    pub fn makeKeyAndOrderFront(self: Self, sender: AnyInstance) void {
        self.any.msg("makeKeyAndOrderFront:", .{ sender }, void);
    }
    
    /// TODO: Correct the signature to use NSObject
    pub fn setDelegate(self: Self, delegate: AnyInstance) void {
        self.any.msg("setDelegate:", .{ delegate }, void);
    }
    
    pub fn center(self: Self) void {
        self.any.msg("center", .{}, void);
    }
    
    pub fn setFrameUsingName(self: Self, name: NSString) bool {
        return self.any.msg("setFrameUsingName:", .{ name }, bool);
    }
    
    pub fn setFrameAutosaveName(self: Self, name: NSString) void {
        self.any.msg("setFrameAutosaveName:", .{ name }, void);
    }
    
    pub fn saveFrameUsingName(self: Self, name: NSString) void {
        self.any.msg("saveFrameUsingName:", .{ name }, void);
    }
};

pub const NSMenu = packed struct { pub usingnamespace foundation.NSObjectDerive(Self); const Self = @This();
    any: AnyInstance,
    
    pub fn addItem(self: Self, item: NSMenuItem) void {
        self.any.msg("addItem:", .{ item }, void);
    }
};

pub const NSMenuItem = packed struct { pub usingnamespace foundation.NSObjectDerive(Self); const Self = @This();
    any: AnyInstance,
    
    pub fn setTitle(self: Self, string: NSString) void {
        self.any.msg("setTitle:", .{ string }, void);
    }
    
    pub fn setSubmenu(self: Self, submenu: NSMenu) void {
        self.any.msg("setSubmenu:", .{ submenu }, void);
    }
};
