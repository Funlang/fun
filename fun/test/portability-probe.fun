// Cross-compiler (Delphi <-> FPC) behaviour probe. Deterministic only: no
// time/random/path/locale-dependent input, so a snapshot generated on one
// compiler can be diffed against another.
//
// Usage on Windows: generate fun/test/expected/portability-probe.fun.txt with
// `run-linux-regression.sh --update`, then diff it against the Linux snapshot.
// Every difference is a place where the two RTLs disagree and the interpreter
// (or a lib) may need to stop relying on the compiler's behaviour.
//
// This file exists because of a real divergence found on 2026-09-12:
// `b := AnsiString(variant)` shares the buffer on FPC but not on Delphi, which
// let CPcre.Replace's raw writes leak into the source string (see
// known-issues/hazards.md H-11 and port-decisions.md D14).
use 'fun/lib/lib-math.fun';

// --- 32/64-bit integer promotion and wrap ---
?. 2147483647 + 1;
?. -2147483648 - 1;
?. 65536 * 65536;
?. 3 ^ 40;

// --- div / mod sign ---
?. -7 div 2; ?. -7 mod 2; ?. 7 div -2; ?. 7 mod -2;

// --- rounding (banker's vs half-away-from-zero?) ---
?. round(0.5); ?. round(1.5); ?. round(2.5); ?. round(-0.5);

// --- float <-> string ---
?. (1/3).toStr();
?. 1e20.toStr();
?. (0.1 + 0.2).toStr();
?. 1.5.toStr();
?. 123456789.123.toStr();

// --- string -> number prefixes ---
?. '0x1F'.toNum(); ?. 'x1F'.toNum(); ?. '$1F'.toNum(); ?. '0b101'.toNum();

// --- char conversions ---
?. 65.toChar();
?. 255.toChar().toByte();
?. 'xff'.toChar().toByte();

// --- ASCII case and comparison ---
?. 'AbC'.upper(); ?. 'AbC'.lower();
?. ('A' = 'a'); ?. ('A' < 'a');

// --- string aliasing / sharing ---
var s1 = 'abcd 1234 efgh'; var r1 = s1.replace(/\d++/g, '0'); ?. s1; ?. r1;
var s2 = 'hello'; var r2 = s2; r2 &= '!'; ?. s2;
var s3 = 'ABCD'; var r3 = s3.substr(1, 2); ?. r3;

// --- lenient vs strict numeric text ---
try ?. '12abc'.toNum(); except ?. 'raise'; end try;
try ?. ' 12 '.toNum(); except ?. 'raise'; end try;

// --- format(): Fun's own spec, NOT Pascal's. Per the comment above _format:
//     String -> %s, Number -> FormatFloat pattern (#/0), DateTime -> Pascal
//     datetime tokens. So only the documented surface is pinned here.
?. 'fmt-s: ' & '%s'.format(42);
?. 'fmt-s2: ' & 'Error: %s at %s/%s.'.format('"a" not found', 10, 3);
?. 'fmt-w: ' & '%8s|'.format('hi');
?. 'fmtfloat: ' & 1.5.format('0.00');
?. 'fmtfloat2: ' & (1/3).format('0.0000');
?. 'fmtfloat3: ' & 1234567.891.format('#,##0.00');

// --- non-ASCII comparison (Fun `=` is ASCII case-insensitive; high bytes
//     compare by code) ---
var ua = 0xC4.toChar();   // A-umlaut
var la = 0xE4.toChar();   // a-umlaut
?. (ua = la);
?. (la < 'z');

// --- substr/Copy result must not alias the source ---
var p1 = 'ABCDEF'; var q1 = p1.substr(0, 3);             q1.fromByte(0, 90); ?. p1; ?. q1;
var p2 = 'ABCDEF'; var q2 = p2.substr(0, p2.length());   q2.fromByte(0, 90); ?. p2; ?. q2;
