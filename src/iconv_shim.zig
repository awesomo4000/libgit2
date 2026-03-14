/// iconv_shim.zig — Pure-Zig iconv replacement for libgit2.
///
/// Exports C-ABI-compatible `iconv_open`, `iconv`, `iconv_close` symbols that
/// back libgit2's NFD→NFC filename normalisation without linking system libiconv.
///
/// Only the encoding pairs libgit2 actually uses are supported:
///   - "UTF-8-MAC" → "UTF-8"  (NFD→NFC, the real work)
///   - "UTF-8"     → "UTF-8"  (identity, no-op passthrough)
///
/// Any other pair returns (iconv_t)-1 — libgit2 handles that gracefully by
/// skipping normalisation.
const std = @import("std");
const Normalize = @import("Normalize");

const allocator = std.heap.c_allocator;

/// Sentinel value matching POSIX `(iconv_t)-1`.
const ICONV_ERROR: usize = @as(usize, 0) -% 1;

const Mode = enum { nfc, identity };

const IconvState = struct {
    mode: Mode,
    norm: Normalize,
};

// ── iconv_open ──────────────────────────────────────────────────────────

export fn iconv_open(tocode: [*:0]const u8, fromcode: [*:0]const u8) usize {
    const to = std.mem.span(tocode);
    const from = std.mem.span(fromcode);

    const mode: Mode = blk: {
        if (std.ascii.eqlIgnoreCase(to, "UTF-8") and std.ascii.eqlIgnoreCase(from, "UTF-8-MAC"))
            break :blk .nfc;
        if (std.ascii.eqlIgnoreCase(to, "UTF-8") and std.ascii.eqlIgnoreCase(from, "UTF-8"))
            break :blk .identity;
        // Unsupported encoding pair.
        return ICONV_ERROR;
    };

    const state = allocator.create(IconvState) catch return ICONV_ERROR;

    if (mode == .nfc) {
        state.* = .{
            .mode = .nfc,
            .norm = Normalize.init(allocator) catch {
                allocator.destroy(state);
                return ICONV_ERROR;
            },
        };
    } else {
        state.* = .{
            .mode = .identity,
            .norm = undefined,
        };
    }

    return @intFromPtr(state);
}

// ── iconv ───────────────────────────────────────────────────────────────

export fn iconv(
    cd: usize,
    inbuf_ptr: ?*[*]u8,
    inbytesleft: ?*usize,
    outbuf_ptr: ?*[*]u8,
    outbytesleft: ?*usize,
) usize {
    // NULL inbuf → reset state (nothing to do for our stateless normaliser).
    if (inbuf_ptr == null) return 0;

    const state: *IconvState = @ptrFromInt(cd);
    const in = inbuf_ptr.?;
    const in_left = inbytesleft.?;
    const out = outbuf_ptr.?;
    const out_left = outbytesleft.?;

    const input = in.*[0..in_left.*];

    switch (state.mode) {
        .identity => {
            // Straight copy — same encoding in and out.
            if (out_left.* < in_left.*) {
                // Copy what fits, advance pointers, signal E2BIG.
                @memcpy(out.*[0..out_left.*], input[0..out_left.*]);
                in.* += out_left.*;
                in_left.* -= out_left.*;
                out.* += out_left.*;
                out_left.* = 0;
                setErrno(.@"2BIG");
                return ICONV_ERROR;
            }
            @memcpy(out.*[0..in_left.*], input);
            out.* += in_left.*;
            out_left.* -= in_left.*;
            in.* += in_left.*;
            in_left.* = 0;
            return 0;
        },
        .nfc => {
            // NFC normalisation via zg.
            const result = state.norm.nfc(allocator, input) catch {
                // Memory allocation failure — treat as conversion error.
                setErrno(.ILSEQ);
                return ICONV_ERROR;
            };
            defer result.deinit(allocator);

            const nfc = result.slice;

            if (nfc.len > out_left.*) {
                // Output buffer too small — copy what fits, signal E2BIG.
                // Because NFC is not byte-for-byte with NFD we cannot do a
                // partial conversion that leaves the iconv pointers in a
                // resumable position. Instead we leave `in` unchanged so
                // libgit2's retry loop will re-try the whole input into a
                // bigger buffer.
                setErrno(.@"2BIG");
                return ICONV_ERROR;
            }

            @memcpy(out.*[0..nfc.len], nfc);
            out.* += nfc.len;
            out_left.* -= nfc.len;
            in.* += in_left.*;
            in_left.* = 0;
            return 0;
        },
    }
}

// ── iconv_close ─────────────────────────────────────────────────────────

export fn iconv_close(cd: usize) c_int {
    const state: *IconvState = @ptrFromInt(cd);
    if (state.mode == .nfc) {
        state.norm.deinit(allocator);
    }
    allocator.destroy(state);
    return 0;
}

// ── helpers ─────────────────────────────────────────────────────────────

fn setErrno(e: std.c.E) void {
    const ptr = std.c._errno();
    ptr.* = @intFromEnum(e);
}
