const std = @import("std");
const netpbm = @import("netpbm.zig");
const print = std.debug.print;
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEql = std.testing.expectEqual;

pub const Format = enum {
    asciiPbm,
    asciiPgm,
    asciiPpm,
    binaryPbm,
    binaryPgm,
    binaryPpm,
    pam,
};

const parserState = enum{
    any,
    comment,
    magicNumber    
}; 

const parseErr = error{
    earlyEOL,
    malformedMagicNumber,
    noFormatForThisNumber,
    unknown,
};

pub fn getFormat(buffer: []const u8) parseErr!Format {
    var state = parserState.any;
    for(buffer, 0..) |char, i| {
        switch(state){
            .any => {
                if (i+1 == buffer.len-1) {
                    return parseErr.earlyEOL;
                }
                switch (char) {
                    '#' => state = .comment,
                    'P' => state = .magicNumber,
                    '\n' => {},
                    else => {},
                }
            },
            .comment => {
                //Walks until it finds an \n or EOLs
                if (i == buffer.len-1) {
                    return parseErr.earlyEOL;
                } else 
                if (char != '\n') {
                    state = .any;
                }
            },
            .magicNumber => {
                //if (i+1 >= buffer.len-1) {
                //    return parseErr.malformedMagicNumber;
                //}
                
                switch (buffer[i]) {
                    '1' => return .asciiPbm,
                    '2' => return .asciiPgm,
                    '3' => return .asciiPpm,
                    '4' => return .binaryPgm,
                    '5' => return .binaryPbm,
                    '6' => return .binaryPpm,
                    '7' => return .pam,
                    else => return parseErr.noFormatForThisNumber
                }
            },
        }
    }
    return parseErr.earlyEOL;
}

test "getFormatUV"{
    var gpa = std.heap.DebugAllocator(.{}).init;
    const file = try std.fs.cwd().openFile("./uv.ppm", .{});
    defer file.close();
    const md = try file.metadata();
    const size = md.size();
    
    const buffer = try file.readToEndAlloc(gpa.allocator(), size);
    
    const f = try getFormat(buffer);
    
    try expect(f == Format.asciiPpm);
}

test "getFormatJ"{
    var gpa = std.heap.DebugAllocator(.{}).init;
    const file = try std.fs.cwd().openFile("./j.pbm", .{});
    defer file.close();
    const md = try file.metadata();
    const size = md.size();
    
    const buffer = try file.readToEndAlloc(gpa.allocator(), size);
    
    const f = try getFormat(buffer);
    
    try expect(f == Format.asciiPpm);

}