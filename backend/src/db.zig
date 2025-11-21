const std = @import("std");
// libpqのCヘッダー定義（簡易版）
pub const c = @cImport({
    @cInclude("libpq-fe.h");
});

pub fn init(allocator: std.mem.Allocator) !void {
    _ = allocator;
    // DB接続初期化処理（必要に応じて実装）
}

pub fn deinit() void {
    // 後処理
}

pub fn query(sql: []const u8) !*c.PGresult {
    _ = sql;
    return error.NotImplemented; // 仮の実装
}

pub fn queryParams(sql: []const u8, params: []const []const u8) !*c.PGresult {
    _ = sql;
    _ = params;
    return error.NotImplemented; // 仮の実装
}

pub fn freeResult(res: *c.PGresult) void {
    _ = res;
}