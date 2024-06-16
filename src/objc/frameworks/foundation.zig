const objc = @import("../objc.zig");

const AnyInstance = objc.AnyInstance;

pub const NSInteger = isize;
pub const NSUInteger = usize;

pub const NSUTF8StringEncoding: NSUInteger = 4;

/// Logs an error message to the Apple System Log facility.
pub extern fn NSLog(format: AnyInstance, ...) void;
