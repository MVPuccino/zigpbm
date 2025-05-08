const std = @import("std");
const netpbm = @import("netpbm.zig");
const print = std.debug.print;
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEql = std.testing.expectEqual;

const Self = @This();

//Not data-oriented at all since a mere `b` pays the price of a whole `p16`,
//but I'll optimize later.
//const Pix = union(enum){
//    b: [48]u1,
//    g8: [6]u8,
//    g16: [3]u16,
//    p8: [2]struct{r: u8, g: u8, b: u8},
//    p16: struct{r: u16, g: u16, b: u16},
//};

width: usize,
height: usize,
format: netpbm.Format,
data: std.ArrayList([3]u8),

const parserState = enum{
    any,
    comment,
    magicNum,
    dimension,
    colorFmt,
    pixels,
}; 

const parseErr = error{
    earlyEOL,
    malformedMagicNumber,
    noFormatForThisNumber,
    pixelsBeforeSize,
    badCharacter,
    unimplemented
};

const fatError = struct {
    err: anyerror,
    index: usize,
};

pub fn parse(buffer: []const u8, allocator: std.mem.Allocator) !Self{
    var width: usize = 0;
    var height: usize = 0;
    var format: netpbm.Format = undefined;
    var data = std.ArrayList([3]u8).init(allocator);
    
    var dimensionTracker: u8 = 2;
    
    var state = parserState.any;
    for (buffer, 0..) |c, i| {
        print("Character: {c}, index: {d}, state: {any}\n", .{c, i, state});
        switch(state){
            .any => {
                switch (c) {
                    '#' => state = .comment,
                    'P' => state = .magicNum,
                    '0'...'9' => {
                        switch (dimensionTracker) {
                            1, 2 => state = .dimension,
                            0 => state = .colorFmt,
                            else => unreachable,
                        }
                    },
                    ' ', '\n' => {},
                    else => return parseErr.badCharacter,
                }
            },
            .comment => {
                if (c == '\n') { //Keep running until a newline is found
                    state = .any;
                }
            },
            .magicNum => {
                switch (c) {
                    '1' => format = .asciiPbm,
                    '2' => format = .asciiPgm,
                    '3' => format = .asciiPpm,
                    '4' => format = .binaryPbm,
                    '5' => format = .binaryPgm,
                    '6' => format = .binaryPpm,
                    '7' => return parseErr.unimplemented,
                    else => {
                        print("Expected number, found {c}\n", .{c}); 
                        return parseErr.noFormatForThisNumber;
                    },
                }
                state = .comment;
            },
            .dimension => {
                const start = i-1;
                var end = i;
                for (buffer[i..buffer.len]) |n| {
                    switch (n) {
                        '0'...'9' => end += 1, //increases the buffer range if a number is found
                        ' ', '\n' => break, //ends the loop if a space or newline is found
                        else => return parseErr.badCharacter, //otherwise errors
                    }
                }
                switch (dimensionTracker) {
                    2 => {width = try std.fmt.parseInt(usize, buffer[start..end], 10); print("width: {d}\n", .{width});},
                    1 => {height = try std.fmt.parseInt(usize, buffer[start..end], 10); print("height: {d}\n", .{height});},
                    else => unreachable,
                }
                
                dimensionTracker -= 1;
                state = .comment;
            },
            .colorFmt => {
                const start = i-1;
                var end = i;
                for (buffer[i..buffer.len]) |n| {
                    switch (n) {
                        '0'...'9' => end += 1, //increases the buffer range if a number is found
                        ' ', '\n' => break, //ends the loop if a space or newline is found
                        else => return parseErr.badCharacter, //otherwise errors
                    }
                }
                const colorFmt = try std.fmt.parseInt(u16, buffer[start..end], 10);
                assert((colorFmt == 255) or ((colorFmt == 65535)));
                
                state = .pixels;
            },
            .pixels => {
                print("Reached pixels\n", .{});
                assert(false);
            },
        }
    }
    
    return Self {
        .width = width,
        .height = height,
        .format = .asciiPpm,
        .data = data,
    };
}

test parse {
    var dbga = std.heap.DebugAllocator(.{}).init;
    
    const file = try std.fs.cwd().openFile("uv.ppm", .{});
    defer file.close();
    const md = try file.metadata();
    
    const buffer = try file.readToEndAlloc(dbga.allocator(), md.size());
    
    const res = try parse(buffer, dbga.allocator());
    
    try expect(res.format == netpbm.Format.asciiPpm);
    try expect(res.width == 255);
    try expect(res.height == 255);
    
}