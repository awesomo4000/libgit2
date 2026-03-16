/// Minimal test that exercises libgit2 the same way gob does.
/// On Linux, directory iteration triggers iconv_open("UTF-8","UTF-8")
/// through git_fs_path_iconv_init_precompose, and cleanup calls iconv_close.
const std = @import("std");

const c = @cImport({
    @cInclude("git2.h");
});

fn toZ(input: []const u8) [4096:0]u8 {
    var buf: [4096:0]u8 = @splat(0);
    const len = @min(input.len, 4095);
    @memcpy(buf[0..len], input[0..len]);
    buf[len] = 0;
    return buf;
}

pub fn main() !void {
    std.debug.print("=== libgit2 iconv shim test ===\n", .{});

    // 1. Init libgit2 (like gob's globalInit)
    _ = c.git_libgit2_init();
    defer _ = c.git_libgit2_shutdown();
    std.debug.print("[OK] git_libgit2_init\n", .{});

    // 2. Create a temp repo (like gob's Repository.create)
    const tmp_path = "/tmp/libgit2-iconv-test";

    // Clean up any previous run
    std.fs.deleteTreeAbsolute(tmp_path) catch {};

    const path_z = toZ(tmp_path);
    const branch_z = toZ("main");

    var opts: c.git_repository_init_options = undefined;
    _ = c.git_repository_init_options_init(&opts, c.GIT_REPOSITORY_INIT_OPTIONS_VERSION);
    opts.flags = c.GIT_REPOSITORY_INIT_MKPATH;
    opts.initial_head = &branch_z;

    var repo: ?*c.git_repository = null;
    var rc = c.git_repository_init_ext(&repo, &path_z, &opts);
    if (rc < 0 or repo == null) {
        std.debug.print("[FAIL] git_repository_init_ext: {d}\n", .{rc});
        return error.InitFailed;
    }
    defer c.git_repository_free(repo.?);
    std.debug.print("[OK] repo created at {s}\n", .{tmp_path});

    // 3. Set config (like gob does)
    {
        var cfg: ?*c.git_config = null;
        if (c.git_repository_config(&cfg, repo.?) < 0 or cfg == null) {
            std.debug.print("[FAIL] git_repository_config\n", .{});
            return error.ConfigFailed;
        }
        defer c.git_config_free(cfg.?);
        const email_k = toZ("user.email");
        const email_v = toZ("test@test.com");
        _ = c.git_config_set_string(cfg.?, &email_k, &email_v);
        const name_k = toZ("user.name");
        const name_v = toZ("test");
        _ = c.git_config_set_string(cfg.?, &name_k, &name_v);
    }
    std.debug.print("[OK] config set\n", .{});

    // 4. Write a test file
    {
        const file_path = tmp_path ++ "/hello.txt";
        const file = try std.fs.createFileAbsolute(file_path, .{});
        try file.writeAll("hello from iconv test\n");
        file.close();
    }
    std.debug.print("[OK] test file written\n", .{});

    // 5. Stage all files (git add -A) — this triggers directory iteration
    //    which on Linux goes through iconv_open/iconv/iconv_close
    {
        var index: ?*c.git_index = null;
        if (c.git_repository_index(&index, repo.?) < 0 or index == null) {
            std.debug.print("[FAIL] git_repository_index\n", .{});
            return error.IndexFailed;
        }
        defer c.git_index_free(index.?);

        var dot: [2]u8 = .{ '.', 0 };
        var dot_ptr: [*c]u8 = &dot;
        const pathspec = c.git_strarray{ .strings = @ptrCast(&dot_ptr), .count = 1 };
        rc = c.git_index_add_all(index.?, &pathspec, c.GIT_INDEX_ADD_DEFAULT, null, null);
        if (rc < 0) {
            std.debug.print("[FAIL] git_index_add_all: {d}\n", .{rc});
            return error.IndexFailed;
        }
        rc = c.git_index_write(index.?);
        if (rc < 0) {
            std.debug.print("[FAIL] git_index_write: {d}\n", .{rc});
            return error.IndexFailed;
        }
    }
    std.debug.print("[OK] git_index_add_all (triggers iconv on Linux)\n", .{});

    // 6. Create a commit (like gob's Repository.commit)
    {
        var index: ?*c.git_index = null;
        if (c.git_repository_index(&index, repo.?) < 0 or index == null)
            return error.IndexFailed;
        defer c.git_index_free(index.?);

        var tree_oid: c.git_oid = undefined;
        if (c.git_index_write_tree(&tree_oid, index.?) < 0)
            return error.TreeFailed;

        var tree: ?*c.git_tree = null;
        if (c.git_tree_lookup(&tree, repo.?, &tree_oid) < 0 or tree == null)
            return error.TreeFailed;
        defer c.git_tree_free(tree.?);

        var sig: ?*c.git_signature = null;
        if (c.git_signature_now(&sig, "test", "test@test.com") < 0 or sig == null)
            return error.CommitFailed;
        defer c.git_signature_free(sig.?);

        const msg_z = toZ("test commit");
        var commit_oid: c.git_oid = undefined;
        rc = c.git_commit_create(
            &commit_oid,
            repo.?,
            "HEAD",
            sig.?,
            sig.?,
            null,
            &msg_z,
            tree.?,
            0,
            null,
        );
        if (rc < 0) {
            std.debug.print("[FAIL] git_commit_create: {d}\n", .{rc});
            return error.CommitFailed;
        }
    }
    std.debug.print("[OK] commit created\n", .{});

    // 7. Cleanup
    std.fs.deleteTreeAbsolute(tmp_path) catch {};
    std.debug.print("[OK] cleanup done\n", .{});

    std.debug.print("\n=== ALL PASSED ===\n", .{});
}
