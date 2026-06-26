const std = @import("std");
const Io = std.Io;

const salvia = @import("salvia");

pub fn main(init: std.process.Init) !void {

    const arena: std.mem.Allocator = init.arena.allocator();

    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);
    switch (args.len) {
        0...1 => {
            std.log.err("No file given!\n", .{});
            return;
        },
        2 => {},
        else => {
            std.log.err("Only one argument is tolerated!\n", .{});
            return;
        },
    }

    const filename = args[1];
    const cwd = std.Io.Dir.cwd();

    const file = cwd.openFile(io, filename, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.log.err("file '{s}' not found\n", .{filename});
            return;
        },
        else => return err,
    };

    var buff: [4096]u8 = undefined; 
    const n = try file.readPositionalAll(io, &buff, 0);
    const content = buff[0..n];

    std.debug.print("{s}", .{content});

    defer file.close(io);
}
