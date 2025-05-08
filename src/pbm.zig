const std = @import("std");
const netpbm = @import("netpbm.zig");
const print = std.debug.print;
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEql = std.testing.expectEqual;

const Self = @This();


width: usize,
height: usize,
format: netpbm.Format,
data: std.ArrayList(u1),

const parserState = enum{
    any,
    comment,
    magicNum,
    dimension,
    parsedWalk, //special state for handling dimension insertion
    //colorFmt,
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

pub fn parse(buffer: []const u8, allocator: std.mem.Allocator) !Self{
    var width: usize = 0;
    var height: usize = 0;
    var format: netpbm.Format = undefined;
    var data = std.ArrayList(u1).init(allocator);
    
    var dimensionTracker: u8 = 2;
    
    var state = parserState.any;
    for (buffer, 0..) |c, i| {
        sw: switch(state){
            .any => {
                switch (c) {
                    '#' => state = .comment,
                    'P' => continue :sw .magicNum,
                    '0'...'9' => {
                        switch (dimensionTracker) {
                            1, 2 => continue :sw .dimension,
                            0 => continue :sw .pixels,
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
                assert(buffer[i] == 'P');
                print("Magic number: {c}{c}\n", .{buffer[i],buffer[i+1]});
                format = try parseMagicNumber(buffer[i+1]);
                assert(format == netpbm.Format.asciiPbm);
                state = .parsedWalk;
            },
            .dimension => {
                print("Numbers left to parse: \"{d}\"\n", .{dimensionTracker});
                var end = i+1;
                for (buffer[i+1..buffer.len]) |n| {
                    switch (n) {
                        '0'...'9' => end += 1, //increases the buffer range if a number is found
                        ' ', '\n' => break, //ends the loop if a space or newline is found
                        else => return parseErr.badCharacter, //otherwise errors
                    }
                }
                switch (dimensionTracker) {
                    2 => {width = try std.fmt.parseInt(usize, buffer[i..end], 10); print("width: {d}\n", .{width});},
                    1 => {height = try std.fmt.parseInt(usize, buffer[i..end], 10); print("height: {d}\n", .{height});},
                    else => unreachable,
                }
                dimensionTracker -= 1;
                state = .parsedWalk;
            },
            .parsedWalk => {
                if (c == '\n' or c == ' ') { //Keep running until a newline is found
                    state = .any;
                }
            },
            .pixels => {
                print("Reached pixels\n", .{});
                try parsePixelBuffer(buffer[i..buffer.len], &data, width, height);
                break;
            },
        }
    }
    
    return Self {
        .width = width,
        .height = height,
        .format = format,
        .data = data,
    };
}

pub fn parseMagicNumber (c: u8) !netpbm.Format{
    switch (c) {
        '1' => return .asciiPbm,
        '2' => return .asciiPgm,
        '3' => return .asciiPpm,
        '4' => return .binaryPbm,
        '5' => return .binaryPgm,
        '6' => return .binaryPpm,
        '7' => return parseErr.unimplemented,
        else => {
            print("Expected number, found {c}\n", .{c}); 
            return parseErr.noFormatForThisNumber;
        },
    }
}

pub fn parsePixelBuffer (buffer: []const u8, list: *std.ArrayList(u1), width: usize, height: usize) !void{
    try list.ensureTotalCapacity(width*height);
    for (buffer) |c| {
        switch (c) {
            '0' => list.appendAssumeCapacity(0),
            '1' => list.appendAssumeCapacity(1),
            ' ', '\n' => {},
            else => return parseErr.badCharacter,
        }
    }    
}

test parse {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const file = try std.fs.cwd().openFile("./testImages/j.pbm", .{});
    defer file.close();
    const md = try file.metadata();
    const size = md.size();
    
    const buffer = try file.readToEndAlloc(gpa.allocator(), size);
    
    var pbm = try parse(buffer, gpa.allocator());
    const list: []const u1 = &.{
        0,0,0,0,0,0,0,
        0,0,0,0,0,1,0,
        0,0,0,0,0,1,0,
        0,0,0,0,0,1,0,
        0,0,0,0,0,1,0,
        0,0,0,0,0,1,0,
        0,0,0,0,0,1,0,
        0,1,0,0,0,1,0,
        0,0,1,1,1,0,0,
        0,0,0,0,0,0,0,
    };
    
    const owned = try pbm.data.toOwnedSlice();
    
    //std.debug.print("{any}\n", .{pbm});
    try expectEql(netpbm.Format.asciiPbm, pbm.format);
    try expect(pbm.width == 7);
    try expect(pbm.height == 10);
    //try expectEql(list, owned);
    try std.testing.expectEqualSlices(u1, list, owned);
}