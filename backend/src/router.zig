const std = @import("std");
const net = std.net;

pub fn route(allocator: std.mem.Allocator, method: std.http.Method, target: []const u8, body: []const u8) ![]u8 {
    _ = method;
    _ = target;
    _ = body;
    
    // とりあえず常に200 OKを返す
    const json = "{\"status\":\"ok\"}";
    return buildJsonResponse(allocator, 200, json);
}

pub fn buildJsonResponse(allocator: std.mem.Allocator, status: u16, json: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, 
        "HTTP/1.1 {d} OK\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: {d}\r\n" ++
        "Connection: close\r\n" ++
        "\r\n" ++
        "{s}",
        .{status, json.len, json}
    );
}