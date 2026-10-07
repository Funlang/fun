// Linux FFI: out-buffers and pointer results (the idioms lib-os needs on Linux).
//
// Two things had to be established before lib-os-style code can run on Linux:
//
//  1. An OUT buffer cannot be passed as a Fun string with type 's'/'p': the
//     engine hands C a pointer to a temporary copy, so writes are discarded.
//     Pass the Fun string's real address instead, as a number:
//         buf = ' '.x(n);  call(buf.toNum(-1), n);
//     (toNum(-1) is the "raw address" form; it is pointer-wide since 8ec0a42.)
//
//  2. A 'p' return must be a signed Int64. It used to come back as PtrUInt
//     (varUInt64), which isNum() rejects on non-Unicode builds, so feeding the
//     result into another FFI call silently passed 0.
use 'fun/lib/lib-utils.fun';

var getcwd = 'libc.so.6'.getapi('getcwd', 'pi:p');
var getenv = 'libc.so.6'.getapi('getenv', 's:p');
var setenv = 'libc.so.6'.getapi('setenv', 'ssi:i');
var strlen = 'libc.so.6'.getapi('strlen', 'p:i');
var strcpy = 'libc.so.6'.getapi('strcpy', 'ps:p');

// --- out-buffer: getcwd writes into the Fun string in place ---
var buf = ' '.x(4097);
var p = getcwd(buf.toNum(-1), 4096);
?. p != nil;
var n = strlen(buf.toNum(-1));
?. n > 0;
?. buf.substr(0, 1) = '/';          // absolute path
?. buf.substr(len: n).length() = n;

// --- out-buffer: strcpy into a Fun string ---
var dst = ' '.x(16);
strcpy(dst.toNum(-1), 'copied-ok');
?. strlen(dst.toNum(-1));
?. dst.substr(len: 9);

// --- pointer return fed back into another call ---
?. setenv('FUN_FFI_TEST_ENV', 'env-value', 1);
var e = getenv('FUN_FFI_TEST_ENV');
?. e > 0;
var ln = strlen(e);
?. ln;
var s = ' '.x(ln + 1);
e.move(s.toNum(-1), ln);
?. s.substr(len: ln);
