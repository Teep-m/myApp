const std = @import("std");
const router = @import("../router.zig");
const db = @import("../db.zig");
const c = @import("../db.zig").c;
const json = std.json;

pub fn list(allocator: std.mem.Allocator) ![]u8 {
    // Query all items
    const sql = "SELECT id, name, description, price, stock, created_at FROM items ORDER BY created_at DESC";
    const result = db.query(sql) catch {
        const err_json = "{\"error\":\"Failed to fetch items\"}";
        return try router.buildJsonResponse(allocator, 500, err_json);
    };
    defer db.freeResult(result);

    const row_count = c.PQntuples(result);

    // Build JSON response
    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    try response.appendSlice("{\"items\":[");

    var i: i32 = 0;
    while (i < row_count) : (i += 1) {
        if (i > 0) try response.appendSlice(",");

        const id = std.mem.span(c.PQgetvalue(result, i, 0));
        const name = std.mem.span(c.PQgetvalue(result, i, 1));
        const description = std.mem.span(c.PQgetvalue(result, i, 2));
        const price = std.mem.span(c.PQgetvalue(result, i, 3));
        const stock = std.mem.span(c.PQgetvalue(result, i, 4));
        const created_at = std.mem.span(c.PQgetvalue(result, i, 5));

        const item_json = try std.fmt.allocPrint(allocator,
            "{{\"id\":\"{s}\",\"name\":\"{s}\",\"description\":\"{s}\",\"price\":{s},\"stock\":{s},\"created_at\":\"{s}\"}}",
            .{ id, name, description, price, stock, created_at }
        );
        defer allocator.free(item_json);

        try response.appendSlice(item_json);
    }

    const total = try std.fmt.allocPrint(allocator, "],\"total\":{d}}}", .{row_count});
    defer allocator.free(total);
    try response.appendSlice(total);

    const json_str = try allocator.dupe(u8, response.items);
    defer allocator.free(json_str);

    return try router.buildJsonResponse(allocator, 200, json_str);
}

pub fn show(allocator: std.mem.Allocator, id: []const u8) ![]u8 {
    // Query single item
    const sql = "SELECT id, name, description, price, stock, created_at FROM items WHERE id = $1";
    const result = db.queryParams(sql, &[_][]const u8{id}) catch {
        const err_json = "{\"error\":\"Failed to fetch item\"}";
        return try router.buildJsonResponse(allocator, 500, err_json);
    };
    defer db.freeResult(result);

    if (c.PQntuples(result) == 0) {
        const err_json = "{\"error\":\"Item not found\"}";
        return try router.buildJsonResponse(allocator, 404, err_json);
    }

    const name = std.mem.span(c.PQgetvalue(result, 0, 1));
    const description = std.mem.span(c.PQgetvalue(result, 0, 2));
    const price = std.mem.span(c.PQgetvalue(result, 0, 3));
    const stock = std.mem.span(c.PQgetvalue(result, 0, 4));
    const created_at = std.mem.span(c.PQgetvalue(result, 0, 5));

    const response_json = try std.fmt.allocPrint(allocator,
        "{{\"item\":{{\"id\":\"{s}\",\"name\":\"{s}\",\"description\":\"{s}\",\"price\":{s},\"stock\":{s},\"created_at\":\"{s}\"}}}}",
        .{ id, name, description, price, stock, created_at }
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
    const description = if (root.get("description")) |d| d.string else "";
    const price_value = root.get("price").?;
    const stock_value = if (root.get("stock")) |s| s else null;

    // Convert price to string
    const price_str = try std.fmt.allocPrint(allocator, "{d}", .{
        if (price_value == .float) price_value.float else @as(f64, @floatFromInt(price_value.integer))
    });
    defer allocator.free(price_str);

    const stock_str = if (stock_value) |s|
        try std.fmt.allocPrint(allocator, "{d}", .{s.integer})
    else
        try allocator.dupe(u8, "0");
    defer allocator.free(stock_str);

    // Insert item
    const sql = "INSERT INTO items (name, description, price, stock) VALUES ($1, $2, $3, $4) RETURNING id, created_at";
    const result = db.queryParams(sql, &[_][]const u8{ name, description, price_str, stock_str }) catch {
        const err_json = "{\"error\":\"Failed to create item\"}";
        return try router.buildJsonResponse(allocator, 500, err_json);
    };
    defer db.freeResult(result);

    const item_id = std.mem.span(c.PQgetvalue(result, 0, 0));
    const created_at = std.mem.span(c.PQgetvalue(result, 0, 1));

    const response_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"Item created successfully\",\"item\":{{\"id\":\"{s}\",\"name\":\"{s}\",\"description\":\"{s}\",\"price\":{s},\"stock\":{s},\"created_at\":\"{s}\"}}}}",
        .{ item_id, name, description, price_str, stock_str, created_at }
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
    const description = if (root.get("description")) |d| d.string else null;

    if (name == null and description == null) {
        const err_json = "{\"error\":\"No fields to update\"}";
        return try router.buildJsonResponse(allocator, 400, err_json);
    }

    const sql = "UPDATE items SET name = COALESCE($1, name), description = COALESCE($2, description) WHERE id = $3 RETURNING name, description, price, stock";
    const name_param = name orelse "";
    const desc_param = description orelse "";

    const result = db.queryParams(sql, &[_][]const u8{ name_param, desc_param, id }) catch {
        const err_json = "{\"error\":\"Failed to update item\"}";
        return try router.buildJsonResponse(allocator, 500, err_json);
    };
    defer db.freeResult(result);

    if (c.PQntuples(result) == 0) {
        const err_json = "{\"error\":\"Item not found\"}";
        return try router.buildJsonResponse(allocator, 404, err_json);
    }

    const updated_name = std.mem.span(c.PQgetvalue(result, 0, 0));
    const updated_desc = std.mem.span(c.PQgetvalue(result, 0, 1));
    const price = std.mem.span(c.PQgetvalue(result, 0, 2));
    const stock = std.mem.span(c.PQgetvalue(result, 0, 3));

    const response_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"Item updated successfully\",\"item\":{{\"id\":\"{s}\",\"name\":\"{s}\",\"description\":\"{s}\",\"price\":{s},\"stock\":{s}}}}}",
        .{ id, updated_name, updated_desc, price, stock }
    );
    defer allocator.free(response_json);

    return try router.buildJsonResponse(allocator, 200, response_json);
}

pub fn delete(allocator: std.mem.Allocator, id: []const u8) ![]u8 {
    // Delete item
    const sql = "DELETE FROM items WHERE id = $1 RETURNING id";
    const result = db.queryParams(sql, &[_][]const u8{id}) catch {
        const err_json = "{\"error\":\"Failed to delete item\"}";
        return try router.buildJsonResponse(allocator, 500, err_json);
    };
    defer db.freeResult(result);

    if (c.PQntuples(result) == 0) {
        const err_json = "{\"error\":\"Item not found\"}";
        return try router.buildJsonResponse(allocator, 404, err_json);
    }

    const response_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"Item deleted successfully\",\"id\":\"{s}\"}}",
        .{id}
    );
    defer allocator.free(response_json);

    return try router.buildJsonResponse(allocator, 200, response_json);
}