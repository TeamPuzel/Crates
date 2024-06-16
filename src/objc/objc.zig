const std = @import("std");
const c = @import("c.zig");

pub const foundation = @import("frameworks/foundation.zig");

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
        if (fn_info.params[0].type != AnyInstance) @compileError("invalid signature");
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
        if (fn_info.params[0].type != AnyClass) @compileError("invalid signature");
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
    
    pub inline fn retain(self: AnyInstance) void {
        objc_retain(self.id);
    }
    
    pub inline fn release(self: AnyInstance) void {
        objc_release(self.id);
    }
};

pub const AnyProtocol = packed struct {
    protocol: *c.Protocol,
    
    pub inline fn named(name: [:0]const u8) AnyProtocol {
        return .{ .protocol = c.objc_getProtocol(name.ptr) orelse std.debug.panic("protocol not found", .{}) };
    }
};

pub const AutoreleasePool = opaque {
    pub inline fn init() *const AutoreleasePool {
        return @ptrCast(objc_autoreleasePoolPush().?);
    }

    pub inline fn deinit(self: *const AutoreleasePool) void {
        objc_autoreleasePoolPop(@constCast(self));
    }
};

pub extern fn objc_retain(c.id) c.id;
pub extern fn objc_release(c.id) void;

pub extern fn objc_autoreleasePoolPush() ?*anyopaque;
pub extern fn objc_autoreleasePoolPop(?*anyopaque) void;

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

/// Do not construct, incomplete type
const BlockLiteral = extern struct {
    isa: *anyopaque,
    flags: u32,
    reserved: u32,
    /// The implementation takes itself as first parameter, otherwise matches signature. Cast this.
    invoke: *const fn(ctx: AnyInstance) callconv(.C) void
    // More fields go here, no need to implement unless I need to create my own blocks
};
