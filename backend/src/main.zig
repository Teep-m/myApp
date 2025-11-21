const std = @import("std");
const net = std.net;

const router = @import("router.zig");
const db = @import("db.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize database connection pool
    try db.init(allocator);
    defer db.deinit();

    // Get port from environment or use default
    const port = getPort();

    // Create server
    const address = try net.Address.parseIp("0.0.0.0", port);
    var server = try address.listen(.{
        .reuse_address = true,
        .reuse_port = true,
    });
    defer server.deinit();

    std.log.info("Server listening on http://0.0.0.0:{d}", .{port});
    std.log.info("Health check: http://0.0.0.0:{d}/health", .{port});
    std.log.info("API endpoints: http://0.0.0.0:{d}/api/*", .{port});

    // Accept connections
    while (true) {
        const connection = try server.accept();

        // Handle each connection in a separate thread
        const thread = try std.Thread.spawn(.{}, handleConnection, .{ allocator, connection });
        thread.detach();
    }
}

fn getPort() u16 {
    const port_str = std.posix.getenv("PORT") orelse "8080";
    return std.fmt.parseInt(u16, port_str, 10) catch 8080;
}

fn handleConnection(allocator: std.mem.Allocator, connection: net.Server.Connection) void {
    defer connection.stream.close();

    handleRequest(allocator, connection) catch |err| {
        std.log.err("Error handling request: {}", .{err});
    };
}

fn handleRequest(allocator: std.mem.Allocator, connection: net.Server.Connection) !void {
    // Read HTTP request
    var buffer: [8192]u8 = undefined;
    const bytes_read = try connection.stream.read(&buffer);

    if (bytes_read == 0) return;

    const request_data = buffer[0..bytes_read];

    // Parse HTTP request line
    var lines = std.mem.splitSequence(u8, request_data, "\r\n");
    const request_line = lines.next() orelse return error.InvalidRequest;

    var parts = std.mem.splitSequence(u8, request_line, " ");
    const method_str = parts.next() orelse return error.InvalidRequest;
    const target = parts.next() orelse return error.InvalidRequest;

    // Parse method
    const method = std.meta.stringToEnum(std.http.Method, method_str) orelse .GET;

    // Get request body if present
    var body: []const u8 = "";
    if (std.mem.indexOf(u8, request_data, "\r\n\r\n")) |header_end| {
        body = request_data[header_end + 4..];
    }

    // Route the request
    const response = try router.route(allocator, method, target, body);
    defer allocator.free(response);

    // Send response
    try connection.stream.writeAll(response);
}

test "basic server test" {
    std.testing.refAllDecls(@This());
}