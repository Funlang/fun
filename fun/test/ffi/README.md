# Linux FFI test cases (git-ignored, local only)

These cases exercise the Linux `getapi()` FFI added in commit `cb40bcd` /
`b782a87` (see `art/notes/linux-x86_64-port.md` §6). They are scratch / local
test cases and are intentionally **not** tracked by git (this whole `fun/test/`
directory is ignored). Kept here so the coverage isn't lost between rebuilds.

## Setup

Build the helper C library once:

```sh
cd fun/test/ffi
gcc -O2 -fPIC -shared -o libffitest.so libffitest.c
```

## Run

All `.fun` cases assume you run from the repo root (they load the helper via
`./fun/test/ffi/libffitest.so`):

```sh
src/prj/fun/funcmd fun/test/ffi/ffi-scalar.fun     # libc/libm + scalar int/double
src/prj/fun/funcmd fun/test/ffi/ffi-float.fun      # float args/returns, mixed GPR/XMM
src/prj/fun/funcmd fun/test/ffi/ffi-int64.fun      # 64-bit int args/returns + cb roundtrip
src/prj/fun/funcmd fun/test/ffi/ffi-callbacks.fun  # int/double/int2/string callbacks
src/prj/fun/funcmd fun/test/ffi/ffi-float-cb.fun   # float cb, void cb, nested cb, two cbs
```

## Coverage matrix

| file | covers |
|------|--------|
| `ffi-scalar.fun` | libc getpid/strlen/atoi/getenv, libm pow/sin (double SSE), helper summ/addi |
| `ffi-float.fun` | fsum/fdbl (float `ff:f`), dfromf (`f:d`), mixsum (`idi:d`), five/ident (double return/id) |
| `ffi-int64.fun` | big64/passll/addll (`l`), int64 callback roundtrip |
| `ffi-callbacks.fun` | `@toCallback` int/double/ii/string cb, cb->string return, repeated calls, zero-arg (`c:i`/`c:v`) cbs |
| `ffi-float-cb.fun` | float cb (`fc:f`), acc double repeat, void cb side-effect, two cbs, nested cb |

## Notes / known limits

- Fun's own numeric literals and arithmetic wrap at 32-bit (a language-level
  limit, unrelated to FFI). Feed true 64-bit values in from C (e.g. via
  `big64`) rather than from a Fun literal when testing the `l` type.
- `'w'` (wide-string) args/returns are accepted on Linux FFI but degrade to the
  narrow `'s'` semantics (wchar_t is 4-byte UTF-32, not UTF-16). They no longer
  raise or crash; treat them as plain char* for ASCII-safe calls.
- Struct / array args and C `long double` / complex returns are not covered.
- The `p` pointer parameter type is passed to Fun as a raw numeric address
  (no automatic dereference); use `ptr=true` on `@toCallback` to hand C a raw
  address instead of a managed closure when needed.
