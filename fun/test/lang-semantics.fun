// Language semantics that the lib fixes depend on.
//
// These are the exact behaviours that made `ret.rows += r[0].rows` and
// `count[n] += 1` silently do nothing (see commits 7b99c22 / 09c22e5). The root
// cause was fixed in src/core/calc.inc (null operands are treated as 0/'' before
// the RTL Variant op), so the `(x or 0) + y` idiom is no longer required - but it
// must keep working, so it is pinned here too.
var s = new [];

// 1) reading a member/index that does not exist compares equal to nil,
//    so the common `if x = nil then x = <init>` guard is safe
?. s.nope = nil;
?. s['nope'] = nil;
?. s[0] = nil;
var t = new [a: 1];
?. t.nope = nil;
?. t['nope'] = nil;

// 2) arithmetic on that missing value treats null as 0 (`Empty op n` is `0 op n`),
//    matching the Delphi build and Fun's own `=` semantics: `x += n` and
//    `x = x + n` really do add `n`.
s.k += 5;
?. s.k;
s.k = s.k + 5;
?. s.k;
var z;
?. z + 1;
?. 1 + z;
?. z + 'a';
?. 'a' + z;
?. z - 1;
?. z * 2;
?. z / 2;
?. z div 2;
?. z mod 2;
// the null operand of a binary op is not modified in place
?. z;
?. (1 + z) = 1;

// 3) `or` is value-returning (Lua style), which is why `(x or 0) + n` works
?. (nil or 0) + 1;
?. (7 or 0) + 1;
var r = new [rows: 7];
?. (r.rows or 0) + 5;

// 4) explicit seeding fixes the accumulator
var acc = new [];
acc.n = (acc.n or 0) + 5;
acc.n = (acc.n or 0) + 2;
?. acc.n;
