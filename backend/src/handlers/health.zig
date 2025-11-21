const std = @import("std");
const router = @import("../router.zig");
const db = @import("../db.zig");

pub fn handle(allocator: std.mem.Allocator) ![]u8 {
    // Check database connection
    const db_status = checkDatabase();

    const timestamp = std.time.timestamp();

    const json = if (db_status)
        try std.fmt.allocPrint(allocator,
            "{{\"status\":\"ok\",\"database\":\"connected\",\"timestamp\":{d}}}",
            .{timestamp})
    else
        try std.fmt.allocPrint(allocator,
            "{{\"status\":\"degraded\",\"database\":\"disconnected\",\"timestamp\":{d}}}",
            .{timestamp});
    defer allocator.free(json);

    const status_code: u16 = if (db_status) 200 else 503;
    return try router.buildJsonResponse(allocator, status_code, json);
}

fn checkDatabase() bool {
    const result = db.query("SELECT 1") catch return false;
    defer db.freeResult(result);
    return true;
}