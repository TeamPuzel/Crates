const std = @import("std");
const objc = @import("../objc.zig");

const AnyClass = objc.AnyClass;
const AnyInstance = objc.AnyInstance;

pub const NSInteger = isize;
pub const NSUInteger = usize;

// pub const NSUTF8StringEncoding: NSUInteger = 4;

/// Logs an error message to the Apple System Log facility.
pub extern fn NSLog(format: NSString, ...) void;

pub const NSObject = packed struct { pub usingnamespace NSObjectDerive(Self); const Self = @This();
    any: AnyInstance
};

pub fn NSObjectDerive(comptime Self: type) type {
    comptime objc.assertClass(Self);
    
    return packed struct {
        any: AnyInstance,
        
        pub fn super() type { return NSObject; }
        
        // Optimization:
        // - Cache this, no need to call into the runtime every time
        // Convenience:
        // - This should register the class if not registered automatically.
        pub fn class() AnyClass {
            const qualified = @typeName(Self);
            comptime var name_iter = std.mem.splitBackwardsScalar(u8, qualified, '.');
            const name = comptime name_iter.next() orelse @typeName(Self);
            comptime var cstr: [name.len:0]u8 = undefined;
            comptime std.mem.copyForwards(u8, &cstr, name);
            const copy = cstr;
            return AnyClass.named(copy[0..]);
        }
        
        pub fn alloc() Self {
            return class().msg("alloc", .{}, Self);
        }
        
        pub fn init(self: Self) Self {
            return self.any.msg("init", .{}, Self);
        }
        
        pub fn autorelease(self: Self) Self {
            return self.any.msg("autorelease", .{}, Self);
        }
        
        pub fn retain(self: Self) Self {
            return self.any.msg("retain", .{}, Self);
        }
        
        pub fn release(self: Self) void {
            self.any.msg("release", .{}, void);
        }
        
        pub fn as(self: Self, comptime Class: type) Class {
            comptime objc.assertClass(Class);
            return Class { .any = self.any };
            // @compileError("safe downcast not implemented yet");
        }
    };
}

/// Convenience function to construct an NSString from a literal.
/// TODO(!): This should construct a static NSString, like the objc `@"str"` syntax.
pub fn NSStr(comptime str: [:0]const u8) NSString {
    return NSString.stringWithUTF8String(str);
}

pub const NSString = packed struct { pub usingnamespace NSObjectDerive(Self); const Self = @This();
    any: AnyInstance,
    
    /// Deprecated
    pub fn stringWithUTF8String(string: [*:0]const u8) @This() {
        return Self.class().msg("stringWithUTF8String:", .{ string }, @This());
    }
};

pub const NSNotification = packed struct { pub usingnamespace NSObjectDerive(Self); const Self = @This();
    any: AnyInstance,
    
    pub fn object(self: Self) AnyInstance {
        return self.any.msg("object", .{}, AnyInstance);
    }
};
