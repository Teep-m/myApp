const std = @import("std");
const router = @import("../router.zig");
const db = @import("../db.zig");
const c = @import("../db.zig").c;
const json = std.json;

pub fn list(allocator: std.mem.Allocator) ![]u8 {
    // Query all users
    const sql = "SELECT id, name, email, created_at FROM users ORDER BY created_at DESC";
    const result = db.query(sql) catch {
        const err_json = "{\"error\":\"Failed to fetch users\"}";
        return try router.buildJsonResponse(allocator, 500, err_json);
    };
    defer db.freeResult(result);

    const row_count = c.PQntuples(result);

    // Build JSON response
    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    try response.appendSlice("{\"users\":[");

    var i: i32 = 0;
    while (i < row_count) : (i += 1) {
        if (i > 0) try response.appendSlice(",");

        const id = std.mem.span(c.PQgetvalue(result, i, 0));
        const name = std.mem.span(c.PQgetvalue(result, i, 1));
        const email = std.mem.span(c.PQgetvalue(result, i, 2));
        const created_at = std.mem.span(c.PQgetvalue(result, i, 3));

        const user_json = try std.fmt.allocPrint(allocator,
            "{{\"id\":\"{s}\",\"name\":\"{s}\",\"email\":\"{s}\",\"created_at\":\"{s}\"}}",
            .{ id, name, email, created_at }
        );
        defer allocator.free(user_json);

        try response.appendSlice(user_json);
    }

    const total = try std.fmt.allocPrint(allocator, "],\"total\":{d}}}", .{row_count});
    defer allocator.free(total);
    try response.appendSlice(total);

    const json_str = try allocator.dupe(u8, response.items);
    defer allocator.free(json_str);

    return try router.buildJsonResponse(allocator, 200, json_str);
}

pub fn show(allocator: std.mem.Allocator, id: []const u8) ![]u8 {
    // Query single user
    const sql = "SELECT id, name, email, created_at FROM users WHERE id = $1";
    const result = db.queryParams(sql, &[_][]const u8{id}) catch {
        const err_json = "{\"error\":\"Failed to fetch user\"}";
        return try router.buildJsonResponse(allocator, 500, err_json);
    };
    defer db.freeResult(result);

    if (c.PQntuples(result) == 0) {
        const err_json = "{\"error\":\"User not found\"}";
        return try router.buildJsonResponse(allocator, 404, err_json);
    }

    const name = std.mem.span(c.PQgetvalue(result, 0, 1));
    const email = std.mem.span(c.PQgetvalue(result, 0, 2));
    const created_at = std.mem.span(c.PQgetvalue(result, 0, 3));

    const response_json = try std.fmt.allocPrint(allocator,
        "{{\"user\":{{\"id\":\"{s}\",\"name\":\"{s}\",\"email\":\"{s}\",\"created_at\":\"{s}\"}}}}",
        .{ id, name, email, created_at }
    );
    defer allocator.free(response_json);

    return try router.buildJsonResponse(allocator, 200, response_json);
}

pub fn create(allocator: std.mem.Allocator, body: []const u8) ![]u8 {
    // Parse JSON
    const parsed = json.parseFromSlice(json.Value, allocator, body, .{}) catch {
        const err_json = "{\"error\":\"Invalid JSON\"}";
        return try router.buildJsonResponse(allocator, 400, err_json);
    };
    defer parsed.deinit();

    const root = parsed.value.object;
    const name = root.get("name").?.string;
    const email = root.get("email").?.string;

    const password_hash = "default_password";

    // Insert user
    const sql = "INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING id, created_at";
    const result = db.queryParams(sql, &[_][]const u8{ name, email, password_hash }) catch {
        const err_json = "{\"error\":\"Failed to create user. Email might already exist.\"}";
        return try router.buildJsonResponse(allocator, 400, err_json);
    };
    defer db.freeResult(result);

    const user_id = std.mem.span(c.PQgetvalue(result, 0, 0));
    const created_at = std.mem.span(c.PQgetvalue(result, 0, 1));

    const response_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"User created successfully\",\"user\":{{\"id\":\"{s}\",\"name\":\"{s}\",\"email\":\"{s}\",\"created_at\":\"{s}\"}}}}",
        .{ user_id, name, email, created_at }
    );
    defer allocator.free(response_json);

    return try router.buildJsonResponse(allocator, 201, response_json);
}

pub fn update(allocator: std.mem.Allocator, id: []const u8, body: []const u8) ![]u8 {
    // Parse JSON
    const parsed = json.parseFromSlice(json.Value, allocator, body, .{}) catch {
        const err_json = "{\"error\":\"Invalid JSON\"}";
        return try router.buildJsonResponse(allocator, 400, err_json);
    };
    defer parsed.deinit();

    const root = parsed.value.object;
    const name = if (root.get("name")) |n| n.string else null;
    const email = if (root.get("email")) |e| e.string else null;

    if (name == null and email == null) {
        const err_json = "{\"error\":\"No fields to update\"}";
        return try router.buildJsonResponse(allocator, 400, err_json);
    }

    var sql_buf: [512]u8 = undefined;
    const sql = if (name != null and email != null)
        try std.fmt.bufPrint(&sql_buf, "UPDATE users SET name = $1, email = $2 WHERE id = $3 RETURNING name, email", .{})
    else if (name != null)
            try std.fmt.bufPrint(&sql_buf, "UPDATE users SET name = $1 WHERE id = $2 RETURNING name, email", .{})
        else
            try std.fmt.bufPrint(&sql_buf, "UPDATE users SET email = $1 WHERE id = $2 RETURNING name, email", .{});

    const params = if (name != null and email != null)
        &[_][]const u8{ name.?, email.?, id }
    else if (name != null)
            &[_][]const u8{ name.?, id }
        else
            &[_][]const u8{ email.?, id };

    const result = db.queryParams(sql, params) catch {
        const err_json = "{\"error\":\"Failed to update user\"}";
        return try router.buildJsonResponse(allocator, 500, err_json);
    };
    defer db.freeResult(result);

    if (c.PQntuples(result) == 0) {
        const err_json = "{\"error\":\"User not found\"}";
        return try router.buildJsonResponse(allocator, 404, err_json);
    }

    const updated_name = std.mem.span(c.PQgetvalue(result, 0, 0));
    const updated_email = std.mem.span(c.PQgetvalue(result, 0, 1));

    const response_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"User updated successfully\",\"user\":{{\"id\":\"{s}\",\"name\":\"{s}\",\"email\":\"{s}\"}}}}",
        .{ id, updated_name, updated_email }
    );
    defer allocator.free(response_json);

    return try router.buildJsonResponse(allocator, 200, response_json);
}

pub fn delete(allocator: std.mem.Allocator, id: []const u8) ![]u8 {
    // Delete user
    const sql = "DELETE FROM users WHERE id = $1 RETURNING id";
    const result = db.queryParams(sql, &[_][]const u8{id}) catch {
        const err_json = "{\"error\":\"Failed to delete user\"}";
        return try router.buildJsonResponse(allocator, 500, err_json);
    };
    defer db.freeResult(result);

    if (c.PQntuples(result) == 0) {
        const err_json = "{\"error\":\"User not found\"}";
        return try router.buildJsonResponse(allocator, 404, err_json);
    }

    const response_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"User deleted successfully\",\"id\":\"{s}\"}}",
        .{id}
    );
    defer allocator.free(response_json);

    return try router.buildJsonResponse(allocator, 200, response_json);
}