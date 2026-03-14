# libgit2

Fork of [allyourcodebase/libgit2](https://github.com/allyourcodebase/libgit2) with system library dependencies replaced by pure-Zig implementations for cross-compilation support.

## Minimal Build (No Network, No System Deps)

For local git operations only (e.g. over an already-established connection), disable transports and TLS to get a zero-system-dependency static library that cross-compiles to any Zig-supported target:

```sh
zig fetch --save git+https://github.com/awesomo4000/libgit2
```

```zig
const libgit2_dep = b.dependency("libgit2", .{
    .target = target,
    .optimize = optimize,
    .@"tls-backend" = .none,
    .@"enable-transports" = false,
});
your_compile_step.linkLibrary(libgit2_dep.artifact("git2"));
```

Cross-compile from the command line:
```sh
zig build -Dtarget=aarch64-linux -Dtls-backend=none -Denable-transports=false
zig build -Dtarget=x86_64-linux  -Dtls-backend=none -Denable-transports=false
```

## Build Options

| Option | Values | Default |
|--------|--------|---------|
| `tls-backend` | `mbedtls`, `openssl`, `securetransport`, `none` | `securetransport` on macOS, `mbedtls` elsewhere |
| `enable-transports` | `true`, `false` | `true` |
| `enable-http` | `true`, `false` | follows `enable-transports` |
| `enable-ntlm` | `true`, `false` | follows `enable-transports` |
| `enable-xdiff` | `true`, `false` | `true` |
| `enable-ssh` | `true`, `false` | `false` |

## Notes

- **iconv**: System `libiconv` has been replaced with a pure-Zig NFC normalizer backed by the [zg](https://codeberg.org/atman/zg) Unicode library. Unicode filename normalization (NFD to NFC) works on all platforms with no system dependencies.
- **securetransport**: Links Apple system frameworks and is not cross-compilable. Use `mbedtls`, `openssl`, or `none` for cross-compilation.
- **ssh**: Requires system `libssh2` and is off by default.

---

## Upstream Usage (allyourcodebase)

This is [libgit2](https://libgit2.org/) packaged using Zig's build system.

While libgit2 supports many different options for system dependencies, I've opted to use [MbedTLS](https://www.trustedfirmware.org/projects/mbed-tls/) by default on Linux for TLS, crypto, and certificate support. You can replace MbedTLS with OpenSSL if you prefer. SSH support is optional, and is provided by [libssh2](https://libssh2.org/).
All other dependencies are bundled in the source tree and compiled statically.

Update your `build.zig.zon`:
```sh
zig fetch --save git+https://github.com/allyourcodebase/libgit2
# or if you want a tagged release
zig fetch --save https://github.com/allyourcodebase/libgit2/archive/refs/tags/${tag}.tar.gz
```

Then, in your `build.zig`, you can access the library as a dependency:
```zig
const libgit2_dep = b.dependency("libgit2", .{
    .target = target,
    .optimize = optimize,
    .@"enable-ssh" = true, // optional ssh support via libssh2
    .@"tls-backend" = .openssl, // use openssl instead of mbedtls
});
your_compile_step.linkLibrary(libgit_dep.artifact("git2"));
```

Don't forget to import headers too:
```zig
const c = @cImport({
    @cInclude("git2.h");
});
```
