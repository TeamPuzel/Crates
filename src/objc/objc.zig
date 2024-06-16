const std = @import("std");
const c = @import("c.zig");

pub const foundation = @import("frameworks/foundation.zig");
pub const cocoa = @import("frameworks/cocoa.zig");

pub const Selector = c.SEL;
pub const nil = AnyInstance { .id = null };

pub const AnyClass = packed struct {
    class: c.Class,
    
    pub inline fn named(name: [:0]const u8) AnyClass {
        return .{ .class = c.objc_getClass(name.ptr) orelse std.debug.panic("class not found", .{}) };
    }
    
    pub inline fn namedSafe(name: [:0]const u8) GetError!AnyClass {
        return .{ .class = c.objc_getClass(name.ptr) orelse return error.DoesNotExist };
    }
    
    pub inline fn msg(self: *const AnyClass, sel: [:0]const u8, args: anytype, comptime Return: type) Return {
        const ArgsType = @TypeOf(args);
        const args_info = @typeInfo(ArgsType);
        if (args_info != .Struct) { @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType)); }
        
        const sel_uid = c.sel_getUid(sel.ptr) orelse unreachable;
        
        const Fn = std.builtin.Type.Fn;
        
        const params: []std.builtin.Type.Fn.Param = params: {
            comptime var acc: [args_info.Struct.fields.len + 2]Fn.Param = undefined;
    
            // First argument is always the target and selector.
            acc[0] = .{ .type = c.Class, .is_generic = false, .is_noalias = false };
            acc[1] = .{ .type = c.SEL, .is_generic = false, .is_noalias = false };
    
            // Remaining arguments depend on the args given, in the order given
            inline for (args_info.Struct.fields, 0..) |field, i| {
                acc[i + 2] = .{
                    .type = field.type,
                    .is_generic = false,
                    .is_noalias = false,
                };
            }
    
            break :params &acc;
        };
        
        const FnInfo = std.builtin.Type { .Fn = .{
            .calling_convention = .C,
            .is_generic = false,
            .is_var_args = false,
            .return_type = Return,
            .params = params
        } };
        
        const cast: *const @Type(FnInfo) = @ptrCast(&c.objc_msgSend);
        return @call(.auto, cast, .{ self.class, sel_uid } ++ args);
    }
    
    pub inline fn new(name: [:0]const u8, super: AnyClass) AnyClass {
        return .{ .class = c.objc_allocateClassPair(super.class, name.ptr, 0) };
    }
    
    pub inline fn register(self: AnyClass) void {
        c.objc_registerClassPair(self.class);
    }
    
    pub inline fn dispose(self: AnyClass) void {
        c.objc_disposeClassPair(self.class);
    }
    
    pub inline fn method(self: AnyClass, name: [:0]const u8, encoding: [:0]const u8, body: anytype) bool {
        const Fn = @TypeOf(body);
        const fn_info = @typeInfo(Fn).Fn;
        if (fn_info.calling_convention != .C) @compileError("invalid calling convention");
        if (fn_info.is_var_args != false) @compileError("methods may not be variadic");
        if (fn_info.params.len < 2) @compileError("invalid signature");
        // TODO: This has false positives
        // if (fn_info.params[0].type != AnyInstance and !isClass(fn_info.params[0].type.?)) @compileError("invalid signature");
        if (fn_info.params[1].type != Selector) @compileError("invalid signature");
        
        const sel = c.sel_registerName(name);
        
        return c.class_addMethod(
            self.class,
            sel,
            @ptrCast(&body),
            encoding.ptr,
        );
    }
    
    pub inline fn override(self: AnyClass, name: [:0]const u8, encoding: [:0]const u8, body: anytype) bool {
        const Fn = @TypeOf(body);
        const fn_info = @typeInfo(Fn).Fn;
        if (fn_info.calling_convention != .C) @compileError("invalid calling convention");
        if (fn_info.is_var_args != false) @compileError("methods may not be variadic");
        if (fn_info.params.len < 2) @compileError("invalid signature");
        // TODO: This has false positives
        // if (fn_info.params[0].type != AnyClass and !isClass(fn_info.params[0].type.?)) @compileError("invalid signature");
        if (fn_info.params[1].type != Selector) @compileError("invalid signature");
        
        const sel = c.sel_registerName(name);
        
        return c.class_replaceMethod(
            self.id,
            sel,
            @ptrCast(&body),
            encoding.ptr,
        );
    }
    
    pub inline fn conform(self: AnyClass, protocol: AnyProtocol) bool {
        return c.class_addProtocol(self.class, protocol.protocol);
    }
    
    pub const GetError = error { DoesNotExist };
    
    comptime {
        if (@sizeOf(AnyClass) != @sizeOf(c.Class)) @compileError("class wrapper not sized correctly");
    }
};

pub const AnyInstance = packed struct {
    id: c.id,
    
    pub inline fn msg(self: AnyInstance, sel: [:0]const u8, args: anytype, comptime Return: type) Return {
        const ArgsType = @TypeOf(args);
        const args_info = @typeInfo(ArgsType);
        if (args_info != .Struct) { @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType)); }
        
        const sel_uid = c.sel_getUid(sel.ptr) orelse unreachable;
        
        const Fn = std.builtin.Type.Fn;
        
        const params: []std.builtin.Type.Fn.Param = params: {
            comptime var acc: [args_info.Struct.fields.len + 2]Fn.Param = undefined;
            
            // First argument is always the target and selector.
            acc[0] = .{ .type = c.id, .is_generic = false, .is_noalias = false };
            acc[1] = .{ .type = c.SEL, .is_generic = false, .is_noalias = false };
            
            // Remaining arguments depend on the args given, in the order given
            inline for (args_info.Struct.fields, 0..) |field, i| {
                acc[i + 2] = .{
                    .type = field.type,
                    .is_generic = false,
                    .is_noalias = false,
                };
            }
            
            break :params &acc;
        };
        
        const FnInfo = std.builtin.Type { .Fn = .{
            .calling_convention = .C,
            .is_generic = false,
            .is_var_args = false,
            .return_type = Return,
            .params = params
        } };
        
        const cast: *const @Type(FnInfo) = @ptrCast(&c.objc_msgSend);
        return @call(.auto, cast, .{ self.id, sel_uid } ++ args);
    }
    
    pub inline fn retain(self: AnyInstance) AnyInstance {
        return .{ .id = objc_retain(self.id) };
    }
    
    pub inline fn release(self: AnyInstance) void {
        objc_release(self.id);
    }
    
    pub inline fn as(self: AnyInstance, comptime Class: type) Class {
        comptime assertClass(Class);
        return Class { .any = self };
        // @compileError("safe downcast not implemented yet");
    }
};

pub const AnyProtocol = packed struct {
    protocol: *c.Protocol,
    
    pub inline fn named(name: [:0]const u8) AnyProtocol {
        return .{ .protocol = c.objc_getProtocol(name.ptr) orelse std.debug.panic("protocol not found", .{}) };
    }
};

pub const AutoReleasePool = opaque {
    pub inline fn init() *const AutoReleasePool {
        return @ptrCast(objc_autoreleasePoolPush().?);
    }

    pub inline fn deinit(self: *const AutoReleasePool) void {
        objc_autoreleasePoolPop(@constCast(self));
    }
};

extern fn objc_retain(c.id) c.id;
extern fn objc_release(c.id) void;

extern fn objc_autoreleasePoolPush() ?*anyopaque;
extern fn objc_autoreleasePoolPop(?*anyopaque) void;

pub fn Block(comptime Args: type, comptime Return: type) type {
    return packed struct { const Self = @This();
        impl: *align(@alignOf(*const fn() callconv(.C) void)) anyopaque,
        
        pub fn invoke(self: Self, args: Args) Return {
            const impl: *BlockLiteral = @ptrCast(self.impl);
            
            const args_info = @typeInfo(Args);
            const Fn = std.builtin.Type.Fn;
            
            const params: []Fn.Param = params: {
                comptime var acc: [args_info.Struct.fields.len + 1]Fn.Param = undefined;
                
                // First argument is always the target and selector.
                acc[0] = .{ .type = AnyInstance, .is_generic = false, .is_noalias = false };
                
                // Remaining arguments depend on the args given, in the order given
                inline for (args_info.Struct.fields, 0..) |field, i| {
                    acc[i + 1] = .{
                        .type = field.type,
                        .is_generic = false,
                        .is_noalias = false,
                    };
                }
                
                break :params &acc;
            };
            
            const FnInfo = std.builtin.Type { .Fn = .{
                .calling_convention = .C,
                .is_generic = false,
                .is_var_args = false,
                .return_type = Return,
                .params = params
            } };
            
            const cast: *const @Type(FnInfo) = @ptrCast(impl.invoke);
            return @call(.auto, cast, .{ AnyInstance { .id = @ptrCast(self.impl) } } ++ args);
        }
    };
}

/// Do not construct, incomplete type.
const BlockLiteral = extern struct {
    isa: *anyopaque,
    flags: u32,
    reserved: u32,
    /// The implementation takes itself as first parameter, otherwise matches signature. Cast this.
    invoke: *const fn(ctx: AnyInstance) callconv(.C) void
    // More fields go here, no need to implement unless I need to create my own blocks
};

pub fn classNameFromType(comptime Class: type) []const u8 {
    const qualified = @typeName(Class);
    comptime var name_iter = std.mem.splitBackwardsScalar(u8, qualified, '.');
    const name = comptime name_iter.next() orelse @typeName(Class);
    comptime var cstr: [name.len:0]u8 = undefined;
    comptime std.mem.copyForwards(u8, &cstr, name);
    const copy = cstr;
    return copy;
}

/// This is currently impossible due to https://github.com/ziglang/zig/issues/6709
///
/// Meta function that registers a class implementation from a Zig class wrapper.
pub fn autoRegisterClass(comptime Class: type) void {
    _ = Class;
    // comptime assertClass(Class);
    // const name = comptime classNameFromType(Class);
    // const info = @typeInfo(Class);
    
    // const super = Class.super().class();
    
    // const class = AnyClass.new(name, super);
    // defer class.register();
    
    // // TODO: Proper signature encoding function
    // inline for (info.Struct.decls) |decl| {
    //     class.method(decl.name, "", @decl(???))
    // }
}

/// Assert that a type is a valid representation of a class.
pub fn assertClass(comptime Class: type) void {
    const info = @typeInfo(Class);
    if (info != .Struct)                                     @compileError("classes must be structs");
    if (info.Struct.layout != .@"packed")                    @compileError("classes must be packed");
    if (info.Struct.fields.len != 1)                         @compileError("classes must have exactly one field");
    if (!std.mem.eql(u8, info.Struct.fields[0].name, "any")) @compileError("the inner name must be \"any\"");
    if (info.Struct.fields[0].type != AnyInstance)           @compileError("the inner type must be \"AnyInstance\"");
}

pub fn isClass(comptime Class: type) bool {
    const info = @typeInfo(Class);
    if (info != .Struct)                                     return false;
    if (info.Struct.layout != .@"packed")                    return false;
    if (info.Struct.fields.len != 1)                         return false;
    if (!std.mem.eql(u8, info.Struct.fields[0].name, "any")) return false;
    if (info.Struct.fields[0].type != AnyInstance)           return false;
    return true;
}
